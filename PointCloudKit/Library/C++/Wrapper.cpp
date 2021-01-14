//
//  Wrapper.cpp
//  Metra
//
//  Created by Alexandre Camilleri on 18/12/2020.
//

#include <string>
#include <stdio.h>

// extern "C" will cause the C++ compiler
// (remember, this is still C++ code!) to
// compile the function in such a way that
// it can be called from C
// (and Swift).

extern "C" int test() {
    return 1;
}
