```text
  _____                         _____                     _    _____
 / ____|                       / ____|                   | |  / ____|_     _
| (___   ___ ___  _ __   ___  | |  __ _   _  __ _ _ __ __| | | |   _| |_ _| |_
 \___ \ / __/ _ \| '_ \ / _ \ | | |_ | | | |/ _` | '__/ _` | | |  |_   _|_   _|
 ____) | (_| (_) | |_) |  __/ | |__| | |_| | (_| | | | (_| | | |____|_|   |_|
|_____/ \___\___/| .__/ \___|  \_____|\__,_|\__,_|_|  \__,_|  \_____|
                 | |
                 |_|
```

[![Github Releases](https://img.shields.io/github/release/Neargye/scope_guard.svg)](https://github.com/Neargye/scope_guard/releases)
[![License](https://img.shields.io/github/license/Neargye/scope_guard.svg)](LICENSE)
[![Build Status](https://travis-ci.org/Neargye/scope_guard.svg?branch=master)](https://travis-ci.org/Neargye/scope_guard)
[![Build status](https://ci.appveyor.com/api/projects/status/yi394vgtwd0i2kco/branch/master?svg=true)](https://ci.appveyor.com/project/Neargye/scope-guard/branch/master)
[![Codacy Badge](https://api.codacy.com/project/badge/Grade/f5aa0553701f4f84bd51f2efda879972)](https://www.codacy.com/app/Neargye/scope_guard?utm_source=github.com&amp;utm_medium=referral&amp;utm_content=Neargye/scope_guard&amp;utm_campaign=Badge_Grade)

# Scope Guard & Defer C++

Scope Guard statement invokes a function with deferred execution until surrounding function returns in cases:

* scope_exit - executing action on scope exit.

* scope_fail - executing action on scope exit when an exception has been thrown before scope exit.

* scope_fail - executing action on scope exit when no exceptions have been thrown before scope exit.

Program control transferring does not influence Scope Guard statement execution. Hence, Scope Guard statement can be used to perform manual resource management, such as file descriptors closing, and to perform actions even if an error occure.

## Features

* C++11
* Header-only
* Dependency-free
* Thin callback wrapping, no added std::function or virtual table penalties
* No implicitly ignored return, check callback return void
* Defer or Scope Guard syntax
* With syntax

## [Examples](example/example.cpp)

* Scope Guard on exit
  ```cpp
  std::fstream file("test.txt");
  SCOPE_EXIT{ file.close(); }; // File closes when exit the enclosing scope or errors occure.
  ```

* Scope Guard on fail
  ```cpp
  persons.push_back(person); // Add the person to db.
  SCOPE_EXIT{ persons.pop_back(); }; // If the errors occure, we should roll back.
  ```

* Scope Guard on succes
  ```cpp
  person = new Person{/*...*/};
  // ...
  SCOPE_SUCCESS{ persons.push_back(person); }; // If no errors occure, we should add the person to db.
  ```

* Custom Scope Guard
  ```cpp
  persons.push_back(person); // Add the person to db.

  MAKE_SCOPE_EXIT(scope_exit) { // Following block is executed when exit the enclosing scope or errors occure.
    persons.pop_back(); // If the db insertion fails, we should roll back.
  };
  // MAKE_SCOPE_EXIT(name) {action} - macro is used to create a new scope_exit object.
  scope_exit.dismiss(); // An exception was not thrown, so don't execute the scope_exit.
  ```
  ```cpp
  persons.push_back(person); // Add the person to db.

  auto scope_exit = make_scope_exit([]() { persons.pop_back(); });
  // make_scope_exit(A&& action) - function is used to create a new scope_exit object. It can be instantiated with a lambda function, a std::function<void()>, a functor, or a void(*)() function pointer.
  // ...
  scope_exit.dismiss(); // An exception was not thrown, so don't execute the scope_exit.
  ```

* With Scope Guard
  ```cpp
  std::fstream file("test.txt");
  WITH_SCOPE_EXIT({ file.close(); }) { // File closes when exit the enclosing with scope or errors occure.
    // ...
  };
  ```

## Synopsis

### Reference

* `SCOPE_EXIT{action};`
* `MAKE_SCOPE_EXIT(name) {action};`
* `WITH_SCOPE_EXIT({action}) {/*...*/};`

* `SCOPE_FAIL{action};`
* `MAKE_SCOPE_FAIL(name) {action};`
* `WITH_SCOPE_FAIL({action}) {/*...*/};`

* `SCOPE_SUCCESS{action};`
* `MAKE_SCOPE_SUCCESS(name) {action};`
* `WITH_SCOPE_SUCCESS({action}) {/*...*/};`

* `DEFER{action};`
* `MAKE_DEFER(name) {action};`
* `WITH_DEFER({action}) {/*...*/};`

* `scope_exit<F> make_scope_exit(F&& action);`
* `scope_fail<F> make_scope_fail(F&& action);`
* `scope_succes<F> make_scope_succes(F&& action);`

### Interface of scope_guard

* `dismiss()` - dismiss executing action on scope exit.

#### Throwable settings:

* `SCOPE_GUARD_MAY_EXCEPTIONS` define this to action may throw exceptions.

* `SCOPE_GUARD_NO_EXCEPTIONS` define this to require noexcept action.

* `SCOPE_GUARD_SUPPRESS_EXCEPTIONS` define this to exceptions during action will be suppressed.

* By default using `SCOPE_GUARD_MAY_EXCEPTIONS`.

### Remarks

* If multiple Scope Guard statements appear in the same scope, the order they appear is the reverse of the order they are executed.
  ```cpp
  void f() {
    SCOPE_EXIT{ std::cout << "First" << std::endl; };
    SCOPE_EXIT{ std::cout << "Second" << std::endl; };
    SCOPE_EXIT{ std::cout << "Third" << std::endl; };
    ... // Other code.
    // Prints "Third".
    // Prints "Second".
    // Prints "First".
  }
  ```

## Integration

You should add required file [scope_guard.hpp](include/scope_guard.hpp).

## Compiler compatibility

* Clang/LLVM >= 5
* Visual C++ >= 14 / Visual Studio >= 2015
* Xcode >= 8
* GCC >= 5

## References

* [Andrei Alexandrescu "Systematic Error Handling in C++"](https://channel9.msdn.com/Shows/Going+Deep/C-and-Beyond-2012-Andrei-Alexandrescu-Systematic-Error-Handling-in-C)
* [Andrei Alexandrescu “Declarative Control Flow"](https://youtu.be/WjTrfoiB0MQ)

## Licensed under the [MIT License](LICENSE)
