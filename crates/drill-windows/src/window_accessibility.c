/* The standard report view supplies navigation, selection, bounds and roles.
 * MSAA needs a property server for text supplied by an owner-data callback. */
#include <oleacc.h>
#include <oleauto.h>
#include <limits.h>
#include <stdlib.h>

typedef struct {
    IAccPropServer server;
    LONG references;
    IAccPropServices *services;
    HWND table;
    DWORD thread;
    DrillModel *model;
    MSAAPROPID properties[2];
} DrillListAccessibility;

static ULONG WINAPI list_acc_addref(IAccPropServer *server) {
    DrillListAccessibility *acc = (DrillListAccessibility *)server;
    return (ULONG)InterlockedIncrement(&acc->references);
}

static ULONG WINAPI list_acc_release(IAccPropServer *server) {
    DrillListAccessibility *acc = (DrillListAccessibility *)server;
    LONG references = InterlockedDecrement(&acc->references);
    if (!references) {
        IAccPropServices_Release(acc->services);
        free(acc);
    }
    return (ULONG)references;
}

static HRESULT WINAPI list_acc_query(IAccPropServer *server, REFIID iid, void **result) {
    if (!result) return E_POINTER;
    *result = NULL;
    if (!IsEqualIID(iid, &IID_IUnknown) && !IsEqualIID(iid, &IID_IAccPropServer))
        return E_NOINTERFACE;
    *result = server;
    list_acc_addref(server);
    return S_OK;
}

/* Match the native list-view convention: the primary cell names the item,
 * and the remaining columns form its comma-separated description. */
static BSTR list_acc_text(const DrillRow *row, bool name) {
    unsigned first = name ? 0 : 1, end = name ? 1 : 4;
    UINT total = 0;
    int lengths[4] = {0};
    for (unsigned i = first; i < end; ++i) {
        lengths[i] = MultiByteToWideChar(CP_UTF8, 0, row->cells[i], -1, NULL, 0);
        if (lengths[i] <= 0) return NULL;
        UINT units = (UINT)(lengths[i] - 1) + (i != first ? 2U : 0U);
        if (units > UINT_MAX / sizeof(WCHAR) - 1 - total) return NULL;
        total += units;
    }
    BSTR text = SysAllocStringLen(NULL, total);
    if (!text) return NULL;
    WCHAR *cursor = text;
    for (unsigned i = first; i < end; ++i) {
        if (i != first) {
            *cursor++ = L',';
            *cursor++ = L' ';
        }
        MultiByteToWideChar(CP_UTF8, 0, row->cells[i], -1, cursor, lengths[i]);
        cursor += lengths[i] - 1;
    }
    return text;
}

static HRESULT WINAPI list_acc_value(IAccPropServer *server, const BYTE *identity, DWORD length,
                                     MSAAPROPID property, VARIANT *value, BOOL *supplied) {
    if (!value || !supplied) return E_POINTER;
    VariantInit(value);
    *supplied = FALSE;
    DrillListAccessibility *acc = (DrillListAccessibility *)server;
    /* Registered in the window's STA. This object does not aggregate the
     * free-threaded marshaler or expose IAgileObject. COM dispatches clients
     * into this apartment. Keep the model inaccessible on other threads. */
    if (GetCurrentThreadId() != acc->thread) return RPC_E_WRONG_THREAD;
    HWND table;
    DWORD object, child;
    if (FAILED(IAccPropServices_DecomposeHwndIdentityString(acc->services, identity, length,
                                                            &table, &object, &child))) return S_OK;
    if (!acc->model) return CO_E_OBJNOTCONNECTED;
    if (table != acc->table || object != (DWORD)OBJID_CLIENT || child == CHILDID_SELF) return S_OK;
    bool name = IsEqualGUID(&property, &PROPID_ACC_NAME);
    if (!name && !IsEqualGUID(&property, &PROPID_ACC_DESCRIPTION)) return S_OK;
    uint64_t id = drill_row_id(acc->model, (size_t)child - 1);
    DrillRow row;
    if (!id || !drill_row(acc->model, id, &row)) return S_OK;
    BSTR text = list_acc_text(&row, name);
    if (!text) return E_OUTOFMEMORY;
    value->bstrVal = text;
    value->vt = VT_BSTR;
    *supplied = TRUE;
    return S_OK;
}

static IAccPropServerVtbl list_acc_vtable = {
    list_acc_query, list_acc_addref, list_acc_release, list_acc_value
};

static DrillListAccessibility *list_accessibility_create(HWND table, DrillModel *model) {
    IAccPropServices *services = NULL;
    if (FAILED(CoCreateInstance(&CLSID_AccPropServices, NULL, CLSCTX_INPROC_SERVER,
                                &IID_IAccPropServices, (void **)&services))) return NULL;
    DrillListAccessibility *acc = calloc(1, sizeof(*acc));
    if (!acc) {
        IAccPropServices_Release(services);
        return NULL;
    }
    acc->server.lpVtbl = &list_acc_vtable;
    acc->references = 1;
    acc->services = services;
    acc->table = table;
    acc->thread = GetCurrentThreadId();
    acc->model = model;
    acc->properties[0] = PROPID_ACC_NAME;
    acc->properties[1] = PROPID_ACC_DESCRIPTION;
    if (FAILED(IAccPropServices_SetHwndPropServer(services, table, OBJID_CLIENT, CHILDID_SELF,
                                                 acc->properties, ARRAYSIZE(acc->properties),
                                                 &acc->server, ANNO_CONTAINER))) {
        list_acc_release(&acc->server);
        return NULL;
    }
    return acc;
}

static void list_accessibility_destroy(DrillListAccessibility *acc) {
    if (!acc) return;
    /* Clients can retain the COM object after the window/model goes away. */
    acc->model = NULL;
    IAccPropServices_ClearHwndProps(acc->services, acc->table, OBJID_CLIENT, CHILDID_SELF,
                                    acc->properties, ARRAYSIZE(acc->properties));
    list_acc_release(&acc->server);
}
