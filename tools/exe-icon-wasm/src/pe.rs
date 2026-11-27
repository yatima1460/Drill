use std::cmp::Reverse;

use crate::resource::byte_range;

const RT_ICON: u32 = 3;
const RT_GROUP_ICON: u32 = 14;
const SUBDIRECTORY: u32 = 1 << 31;
const MAX_SECTIONS: usize = 96; // Windows loader limit.
const MAX_FRAME_SIZE: u32 = 4 * 1024 * 1024;

// An ICO entry and a group entry share these first 12 bytes, up to the byte count.
pub(super) struct IconFrame<'a> {
    pub directory_fields: &'a [u8],
    pub bytes: &'a [u8],
}

pub(super) fn icon_frame(input: &[u8]) -> Option<IconFrame<'_>> {
    let (pe, resource_rva, resource_size) = Pe::parse(input)?;
    let resources = pe.file_backed(resource_rva)?;
    let resources = resources.get(..resources.len().min(resource_size as usize))?;

    let root = entries(resources, 0)?;
    let mut groups = subdirectory(resources, find_id(root, RT_GROUP_ICON)?)?;
    // Named and numeric groups appear in selection order in the resource table.
    let group = first_language(resources, groups.next()?)?;
    let group_start = group.rva.checked_sub(resource_rva)?;
    let group_range = byte_range(u64::from(group_start), group.size, resources.len() as u32)?;
    let group_data = resources.get(group_range)?;
    if u16_at(group_data, 0)? != 0 || u16_at(group_data, 2)? != 1 {
        return None;
    }
    let frame_count = usize::from(u16_at(group_data, 4)?);
    let selected = group_data
        .get(6..6 + frame_count * 14)?
        .chunks_exact(14)
        .filter(|frame| u32_at(frame, 8).is_some_and(|size| size <= MAX_FRAME_SIZE))
        .min_by_key(|frame| {
            let dimension = |value: u8| if value == 0 { 256 } else { u16::from(value) };
            let distance = dimension(frame[0]).abs_diff(32) + dimension(frame[1]).abs_diff(32);
            (distance, Reverse(u16::from_le_bytes([frame[6], frame[7]])))
        })?;

    let icons = subdirectory(resources, find_id(entries(resources, 0)?, RT_ICON)?)?;
    let id = u32::from(u16_at(selected, 12)?);
    let icon = first_language(resources, find_id(icons, id)?)?;
    let size = u32_at(selected, 8)?;
    if size > icon.size {
        return None;
    }
    Some(IconFrame {
        directory_fields: &selected[..12],
        bytes: pe.file_backed(icon.rva)?.get(..size as usize)?,
    })
}

struct Pe<'a> {
    file: &'a [u8],
    sections: &'a [u8],
}

impl<'a> Pe<'a> {
    // PE32 and PE32+ differ in the optional header layout. In both formats the
    // section table follows the length declared in the COFF header.
    fn parse(file: &'a [u8]) -> Option<(Self, u32, u32)> {
        if file.get(..2)? != b"MZ" {
            return None;
        }
        let pe_offset = u32_at(file, 0x3c)? as usize;
        let headers = file.get(pe_offset..)?;
        if headers.get(..4)? != b"PE\0\0" {
            return None;
        }
        let section_count = usize::from(u16_at(headers, 6)?);
        if section_count > MAX_SECTIONS {
            return None;
        }
        let optional_size = usize::from(u16_at(headers, 20)?);
        let section_offset = 24 + optional_size;
        let optional = headers.get(24..section_offset)?;
        let directory_count_offset = match u16_at(optional, 0)? {
            0x10b => 92,
            0x20b => 108,
            _ => return None,
        };
        if u32_at(optional, directory_count_offset)? < 3 {
            return None;
        }
        let resource_rva = u32_at(optional, directory_count_offset + 20)?;
        let resource_size = u32_at(optional, directory_count_offset + 24)?;
        if resource_rva == 0 || resource_size == 0 {
            return None;
        }
        let sections = headers.get(section_offset..section_offset + section_count * 40)?;
        Some((Self { file, sections }, resource_rva, resource_size))
    }

    fn file_backed(&self, rva: u32) -> Option<&'a [u8]> {
        // Prefer the closest preceding section start. An oversized earlier
        // section can overlap the resource section in some executable images.
        let section = self
            .sections
            .rchunks_exact(40)
            .filter(|section| section_address(section) <= rva)
            .max_by_key(|section| section_address(section))?;
        let delta = rva - section_address(section);
        let raw_size = u32_at(section, 16)?;
        let raw_start = u32_at(section, 20)?;
        let file_len = u32::try_from(self.file.len()).ok()?;
        let range = byte_range(u64::from(raw_start), raw_size, file_len)?;
        // Section padding can extend beyond VirtualSize and is file-backed.
        // A virtual-only tail has no corresponding bytes in the snapshot.
        let bytes = self.file.get(range)?.get(delta as usize..)?;
        (!bytes.is_empty()).then_some(bytes)
    }
}

fn section_address(section: &[u8]) -> u32 {
    u32::from_le_bytes([section[12], section[13], section[14], section[15]])
}

struct Entry {
    id: u32,
    offset: u32,
}

fn entries(resources: &[u8], offset: u32) -> Option<impl Iterator<Item = Entry> + '_> {
    let table = resources.get(offset as usize..)?;
    let count = usize::from(u16_at(table, 12)?) + usize::from(u16_at(table, 14)?);
    let (rows, _) = table.get(16..16 + count * 8)?.as_chunks::<8>();
    Some(rows.iter().map(|&[a, b, c, d, e, f, g, h]| Entry {
        id: u32::from_le_bytes([a, b, c, d]),
        offset: u32::from_le_bytes([e, f, g, h]),
    }))
}

fn find_id(mut entries: impl Iterator<Item = Entry>, id: u32) -> Option<Entry> {
    entries.find(|entry| entry.id == id)
}

fn subdirectory(resources: &[u8], entry: Entry) -> Option<impl Iterator<Item = Entry> + '_> {
    entries(resources, entry.offset.checked_sub(SUBDIRECTORY)?)
}

struct ResourceData {
    rva: u32,
    size: u32,
}

fn first_language(resources: &[u8], name: Entry) -> Option<ResourceData> {
    let language = subdirectory(resources, name)?.next()?;
    if language.offset & SUBDIRECTORY != 0 {
        return None;
    }
    let leaf = resources.get(language.offset as usize..)?.get(..16)?;
    Some(ResourceData {
        rva: u32_at(leaf, 0)?,
        size: u32_at(leaf, 4)?,
    })
}

fn u16_at(bytes: &[u8], offset: usize) -> Option<u16> {
    Some(u16::from_le_bytes(
        bytes.get(offset..)?.first_chunk().copied()?,
    ))
}

fn u32_at(bytes: &[u8], offset: usize) -> Option<u32> {
    Some(u32::from_le_bytes(
        bytes.get(offset..)?.first_chunk().copied()?,
    ))
}
