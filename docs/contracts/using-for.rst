.. index:: ! using for, library

.. _using-for:

*********
Using For
*********

The directive ``using A for B;`` can be used to attach
functions (``A``) as member functions to any type (``B``).
These functions will receive the object they are called on
as their first parameter (like the ``self`` variable in Python).

The first part, ``A``, can be one of:

- a list of file-level functions (``using {f, g, h} for uint;``) -
  only those functions will be attached to the type.
- the name of a module (``import "module.sol" as M; using M for uint;``) -
  all file-level functions inside the given module are attached to the type,
  even if the functions are imported.
- the name of a library (``using L for uint;``) -
  all functions (both public and internal ones) of the library are attached to the type
- the asterisk (``using * for uint;``) -
  all file-level functions in the current module are attached.

The directive can be used either inside a contract or at file level,
the last version (``using * for T;``) can only be used at file level.

Inside contracts, you can also use ``using A for *;``,
which has the effect that the functions are attached to *all* types.

Unless you specify the functions explicitly, *all* functions in the
module or library are attached,
even those where the type of the first parameter does not
match the type of the object. The type is checked at the
point the function is called and function overload
resolution is performed.

The ``using A for B;`` directive is active only within the current
scope (either the contract or the current module),
including within all of its functions, and has no effect
outside of the contract or module in which it is used. The directive
may only be used inside a contract, not inside any of its functions.

Let us rewrite the set example from the
:ref:`libraries` in this way, using file-level functions
instead of library functions.

.. code-block:: solidity

    // SPDX-License-Identifier: GPL-3.0
    pragma solidity ^0.8.11;

    struct Data { mapping(uint => bool) flags; }
    // Here, we attach functions to the type.
    // This is valid in all of the module.
    // If you import the module, you have to
    // repeat the statement there, potentially as
    //   import "flags.sol" as Flags;
    //   using Flags for Flags.Data;
    using {insert, remove, contains} for Data;

    function insert(Data storage self, uint value)
        returns (bool)
    {
        if (self.flags[value])
            return false; // already there
        self.flags[value] = true;
        return true;
    }

    function remove(Data storage self, uint value)
        returns (bool)
    {
        if (!self.flags[value])
            return false; // not there
        self.flags[value] = false;
        return true;
    }

    function contains(Data storage self, uint value)
        public
        view
        returns (bool)
    {
        return self.flags[value];
    }


    contract C {
        Data knownValues;

        function register(uint value) public {
            // Here, all variables of type Data have
            // corresponding member functions.
            // The following function call is identical to
            // `Set.insert(knownValues, value)`
            require(knownValues.insert(value));
        }
    }

It is also possible to extend elementary types in that way:

.. code-block:: solidity

    // SPDX-License-Identifier: GPL-3.0
    pragma solidity >=0.6.8 <0.9.0;

    library Search {
        function indexOf(uint[] storage self, uint value)
            public
            view
            returns (uint)
        {
            for (uint i = 0; i < self.length; i++)
                if (self[i] == value) return i;
            return type(uint).max;
        }
    }

    contract C {
        using Search for uint[];
        uint[] data;

        function append(uint value) public {
            data.push(value);
        }

        function replace(uint _old, uint _new) public {
            // This performs the library function call
            uint index = data.indexOf(_old);
            if (index == type(uint).max)
                data.push(_new);
            else
                data[index] = _new;
        }
    }

Note that all external library calls are actual EVM function calls. This means that
if you pass memory or value types, a copy will be performed, even of the
``self`` variable. The only situation where no copy will be performed
is when storage reference variables are used or when internal library
functions are called.
