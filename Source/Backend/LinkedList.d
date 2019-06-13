module robikstuff.LinkedList;

import std.algorithm;

/**
 * Represents doubly linked list.
 * 
 * Adding or removing elements at both list ends is constant time,
 * accessing element at specified index takes O(n).
 * List length is cached internally, so accessing list length is always O(1).
 * 
 * Main linked list methods:
 * 
 *  - addLast(el) append(el)
 *    Adds element to end of the list.
 * 
 *  - addFirst(el) prepend(el)
 *    Adds element to beggining of the list.
 * 
 *  - insertAt(index, el)
 *    Inserts element at specified index.
 * 
 *  - removeFirst()
 *    Removes element from beggining of the list.
 * 
 *  - removeLast()
 *    Removes element from end of the list.
 * 
 *  - removeAt(index)
 *    Removes element from list at specified index.
 * 
 *  - replaceAt(index, el)
 *    Replaces element data with new data specified at index.
 * 
 *  - toArray()
 *    Creates array with list data.
 * 
 *  - clear()
 *    Removes all element in list.
 * 
 * 
 * Properties:
 * 
 *  - .empty
 *    Determines if list has no elements.
 * 
 *  - .length
 *    Number of elements in list.
 * 
 *  - .first
 *    First element in list. May be the same as .last if list has one element.
 * 
 *  - .last
 *    Last element in list. May be the same as .first if list has one element.
 * 
 *  - .range
 *    Returns range that iterates list.
 * 
 * 
 * Operators overloaded:
 * 
 *  - index, slice, equals, in, dollar
 * 
 * Examples:
 * ---
 * auto list = new List!string;
 * list.append("a");
 * list.append("b");
 * assert(list[0] == "a");
 * assert(list[-1] == "b");
 * 
 * writeln(map!`a ~ "_1"`(list));
 * ---
 */
class LinkedList(T)
{
    protected Node* _first;
    protected Node* _last;
    protected size_t _count;
    
    protected struct Node
    {
        T data;
        Node* prev;
        Node* next;
        
        this(T data, Node* prev = null, Node* next = null)
        {
            this.data = data;
            this.prev = prev;
            this.next = next;
        }
    }
    
    
    /*
     * Returns pointer to node at specified index.
     * 
     * Null if index is out of range
     */
    protected Node* nodeAt(size_t i)
    {
        auto n = _first;
        
        if(!i) return n;
        
        while(n !is null)
        {
            if(--i == 0) break;
            
            n = n.next;
        }
        
        return n;
    }
    
    
    /*
     * Returns pointer to node at specified index, starting from end.
     * 
     * Null if index is out of range
     */
    protected Node* nodeAtFromEnd(size_t i)
    {
        auto n = _last;
        
        if(!i) return n;
        
        while(n !is null)
        {
            if(--i == 0) break;
            
            n = n.prev;
        }
        
        return n;
    }
    
    
    /**
     * Adds element at end of the list.
     * 
     * Params:
     *  el = Element to add
     */
    void addLast(T el)
    {
        _count += 1;
        
        if(_first is null) {
            _first = new Node(el);
            _last = _first;
        } else {
            auto n = new Node(el, _last);
            _last.next = n;
            _last = n;
        }
    }
    
    
    /// ditto
    alias append = addLast;
    
    
    /**
     * Adds element to beggining of the list.
     * 
     * Params:
     *  el = Element to add
     */
    void addFirst(T el)
    {
        _count += 1;
        auto n = new Node(el, null, _first);
        if(_first !is null)
            _first.prev = n;
        else
            _last = n;
        _first = n;
    }
    
    
    /// ditto
    alias prepend = addFirst;
    
    
    /**
     * Inserts element at specifed element in list.
     * 
     * If index is 0 or equal to list length, cost is constant,
     * otherwise it's linear.
     * 
     * Params:
     *  index = Index at which insert element
     *  el = Element to insert
     * 
     * Throws:
     *  OutOfRange if index is bigger than list length.
     */
    void insertAt(size_t index, T el)
    {   
        if(index == 0) {
            prepend(el);
        } else if(index == _count) {
            append(el);
        } else {
            auto node = nodeAt(index);
            if(node is null) {
                throw new OutOfRange();
            }
            
            _count += 1;
            auto n = new Node(el, node, node.next);
            node.next.prev = n;
            node.next = n;
        }
    }
    
    
    /**
     * Removes first element from list
     * 
     * Throws:
     *  AssertError if list is empty.
     */
    void removeFirst()
    {
        assert(!empty, "Cannot remove element from empty list.");
        _count -= 1;
        if(_first.next is null) {
            _first = null;
        } else {
            _first = _first.next;
        }
    }
    
    
    /**
     * Removes first element from list
     * 
     * Throws:
     *  AssertError if list is empty.
     */
    void removeLast()
    {
        assert(!empty, "Cannot remove element from empty list.");
        _count -= 1;
        _last = _last.prev;
        _last.next = null;
    }
    
    
    /**
     * Removes element from list with specified index.
     * 
     * Params:
     *  index = Index of element to remove.
     */
    void removeAt(size_t index)
    {
        if(index == 0) {
            removeFirst();
        } else if(index == _count - 1) {
            removeLast();
        } else {
            auto node = nodeAt(index + 1);
            if(node is null) {
                throw new OutOfRange();
            }
            _count -= 1;
            node.prev.next = node.next;
            node.next.prev = node.prev;
        }
    }
    
    
    /**
     * Replaces element at specified index.
     * 
     * Params:
     *  index = Index of element to replace
     *  el = Value to replace with
     */
    void replaceAt(size_t index, T el)
    {
        auto n = nodeAt(index + 1);
        if(n is null) {
            throw new OutOfRange();
        }
        
        n.data = el;
    }
    
    
    /**
     * Removes all elements from list
     */
    void clear()
    {
        _first = null;
        _last = null;
    }
    
    
    /**
     * Creates new array with list data.
     * 
     * Algorithm complexity is O(n)
     * 
     * Returns:
     *  Array with list data
     */
    T[] toArray()
    {
        T[] ret;
        ret.reserve(_count);
        auto n = _first;
        
        while(n !is null) {
            ret ~= n.data;
            n = n.next;
        }
        
        return ret;
    }
    
    
    /**
     * Checks if list is empty
     * 
     * Returns:
     *  True if list has no elements, false otherwise.
     */
    @property bool empty()
    {
        return _first is null;
    }
    
    
    /**
     * Number of elements in list.
     * 
     * List length is cached, and accessing it takes O(1).
     * 
     * Returns:
     *  List length
     */
    @property size_t length()
    {   
        return _count;
    }
    
    
    /**
     * Value of first element.
     * 
     * Throws:
     *  AssetsError if list is empty
     * 
     * Returns:
     *  First element
     */
    @property T first()
    {
        if(_first is null) {
            assert(0, "Trying to read from empty list");
        }
        
        return _first.data;
    }
    
    
    /**
     * Value of last element.
     * 
     * Throws:
     *  AssetsError if list is empty
     * 
     * Returns:
     *  Last element
     */
    @property T last()
    {
        if(_last is null) {
            assert(0, "Trying to read from empty list");
        }
        
        return _last.data;
    }
    
    
    /**
     * List range
     */
    @property ListRange range()
    {
        return ListRange(_first, _last);
    }
    
    
    // -------------------------- OPERATORS -------------------------------------
    
    /**
     * Checks if specified element is in list.
     * 
     * Performs O(n) operations.
     * 
     * Returns:
     *  True if element is in list, false otherwise.
     */
    bool opIn_r(T el)
    {
        return (countUntil(range, el) > -1);
    }
    
    
    /**
     * Gets element at specified index.
     * 
     * Performs O(n) operations.
     * 
     * Params:
     *  index = Element index. Can be negative.
     * 
     * Returns:
     *  Element data
     */
    T opIndex(ptrdiff_t index)
    {
        Node* node;
        if(index < 0) {
            index = _count + index;
            node = nodeAtFromEnd(index - 1);
        } else {
            node = nodeAt(index + 1);
        }
        
        
        if(node is null) {
            throw new OutOfRange();
        }
        
        return node.data;
    }
    
    
    /**
     * Gets elements with specic indexes.
     * 
     * Throws:
     *  OutOfRange if any of indexes is bigger than list length.
     * 
     * Params:
     *  indexes... = Array of indexes
     * 
     * Returns:
     *  Elements
     */
    T[] opIndex(ptrdiff_t[] indexes...)
    {
        T[] ret;
        ret.reserve(indexes.length);
        
        foreach(i; indexes)
        {
            ret ~= this[i];
        }
        
        return ret;
    }
    
    
    /**
     * Gets list elements fitting specified range.
     * 
     * Negative indexes are supported.
     * 
     * Params:
     *  start = Start index
     *  end = End index.
     * 
     * Returns:
     *  Array of list elements sliced
     */
    T[] opSlice(ptrdiff_t start, ptrdiff_t end)
    {
        if(start < 0)
            start = _count + start;
        
        if(end < 0)
            end = _count + end;
        
        T[] ret;
        ptrdiff_t diff;
        
        if(start < end)
            diff = end - start;
        else if(start > end)
            diff = start - end;
        
        ret.reserve(diff);
        auto node = nodeAt(start + 1);
            
        if(node is null) {
            throw new OutOfRange();
        }
        
        while(node !is null && diff--) 
        {
            ret ~= node.data;
            
            if(start < end)
                node = node.next;
            else
                node = node.prev;
        }
        
        return ret;
    }
    
    
    /**
     * Compares two lists.
     */
    override bool opEquals(Object o)
    {
        auto list = cast(typeof(this))o;
        
        if(list is null)
            return false;
        
        if(list.length != this.length)
            return false;
        
        auto node = _first;
        foreach(element; list.range)
        {
            if(element != node.data)
                return false;
            
            node = node.next;
        }
        
        return true;
    }
    
    
    /**
     * Gets list length
     * 
     * Allows for '$' usage in list indexing or slicing.
     */
    size_t opDollar(size_t dimm)()
    {
        return _count;
    }
    
    // -------------------------- RANGE -------------------------------------
    
    private struct ListRange
    {
        private Node* _front;
        private Node* _back;
        
        
        
        this(Node* back, Node* last)
        {
            _front = back;
            _back = last;
        }
        
        
        @property bool empty()
        {
            return (_front is null) || (_back is null);
        }
        
        
        void popFront()
        {
            _front = _front.next;
        }
        
        
        T front()
        {
            return _front.data;
        }
        
        void popBack()
        {
            _back = _back.prev;
        }
        
        T back()
        {
            return _back.data;
        }
        
        
        ListRange save()
        {
            return this;
        }
    }
    
}

unittest
{
    import std.array;
    
    void assertThrows(void delegate() dg)
    {
        try {
            dg();
            assert(false);
        } catch{}
    }
    
    auto list = new LinkedList!int;
    assert(list.empty);
    assert(list.length == 0);
    
    list.addLast(1);
    assert(list.first == list.last);
    assert(list.last == 1);
    assert(list.length == 1);
    assert(list.toArray() == [1]);
    assert(!list.empty);
    
    list.insertAt(1, 3);
    assert(list.toArray() == [1, 3]);
    assert(list.length == 2);
    assert(list.last == 3);
    
    list.insertAt(1, 2);
    assert(list.toArray() == [1, 2, 3]);
    assert(list.length == 3);
    assert(list.last == 3);
    
    list.insertAt(0, 0);
    assert(list.toArray() == [0, 1, 2, 3]);
    assert(list.length == 4);
    
    list.addFirst(-1);
    assert(list.toArray() == [-1, 0, 1, 2, 3]);
    assert(list.length == 5);
    
    list.replaceAt(0, -2);
    assert(list.first == -2);
    assert(list.toArray() == [-2, 0, 1, 2, 3]);
    assert(2 in list);
    
    list.removeFirst();
    assert(list.toArray() == [0,1,2,3]);
    assert(list[1] == 1);
    assert(list[-1] == 2);
    assert(list.first == 0);
    assert(list.length == 4);
    
    
    list.replaceAt(3, 6);
    assert(list.last == 6);
    assert(list.toArray() == [0, 1, 2, 6]);
    
    list.removeLast();
    assert(list.toArray() == [0,1,2]);
    assert(list.length == 3);
    assert(list.last == 2);
    
    list.replaceAt(1, 11);
    assert(list.toArray() == [0,11,2]);
    
    list.removeAt(1);
    assert(list.toArray() == [0,2]);
    assert(list.length == 2);
    assert(list.last == 2);
    
    list.removeAt(1);
    assert(list.toArray() == [0]);
    assert(list.length == 1);
    assert(list.last == 0);
    
    assertThrows({
        list.removeAt(1);
    });
    list.removeAt(0);
    assert(list.toArray() == []);
    assert(list.length == 0);
    assertThrows({
        list.last;
    });
    
    auto list2 = new LinkedList!string;
    list2.addFirst("a");
    assert(list2.first == list2.last);
    assert(list2.first == "a");
    assert(list2.length == 1);
    list2.clear();
    assertThrows({
            list.first;
    });
    assertThrows({
            list.last;
    });
    
    assert(list2.empty);
    list2.addLast("a");
    
    list2 = new LinkedList!string;
    assert(list2.empty);
    assertThrows({
        list2.first;
    });
    list2.addLast("first");
    assert(!list2.empty);
    assert(list2.first == "first");
    assert(list2.first == list2.last);
    
    list2.addLast("second");    
    assert("second" in list2);
    assert(array(list2.range) == ["first", "second"]);
    
    assert(list2[0..1] == ["first"]);
    assert(list2[1..0] == ["second"]);
    assert(list2[1..2] == ["second"]);
    assert(list2[$-1] == "second");
    assert(list2[$-2] == "first");
    
    assertThrows({
        list2[2..1];
    });
    
    auto list3 = new LinkedList!string;
    list3.append("first");
    assert(list3 != list2);
    list3.append("second");
    assert(list3 == list2);
}
