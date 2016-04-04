//
//  BinMask.swift
//  MercadoPagoSDK
//
//  Created by Matias Gualino on 6/3/15.
//  Copyright (c) 2015 com.mercadopago. All rights reserved.
//

import Foundation

public class BinMask : Equatable {
    public var exclusionPattern : String!
    public var installmentsPattern : String!
    public var pattern : String!
    

    public class func fromJSON(json : NSDictionary) -> BinMask {
        let binMask : BinMask = BinMask()
        binMask.exclusionPattern = JSON(json["exclusion_pattern"]!).asString
        binMask.installmentsPattern = JSON(json["installments_pattern"]!).asString
        binMask.pattern = JSON(json["pattern"]!).asString
        return binMask
    }
}


public func ==(obj1: BinMask, obj2: BinMask) -> Bool {
    
    let areEqual =
        obj1.exclusionPattern == obj2.exclusionPattern &&
        obj1.installmentsPattern == obj2.installmentsPattern &&
        obj1.pattern == obj2.pattern
    
    return areEqual
}