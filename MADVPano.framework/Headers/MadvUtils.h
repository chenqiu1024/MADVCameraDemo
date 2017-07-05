//
//  MadvUtils.hpp
//  Madv360_v1
//
//  Created by QiuDong on 2017/5/10.
//  Copyright © 2017年 Cyllenge. All rights reserved.
//

#ifndef MadvUtils_hpp
#define MadvUtils_hpp

#ifdef __cplusplus
extern "C" {
#endif

int copyGyroMatrixFromString(float* matrix, const char* gyroString);

#ifdef __cplusplus
}
#endif

#endif /* MadvUtils_hpp */
