//
//  NestTests.swift
//  NestTests
//
//  Created by Constantinos Liapis on 04/03/2017.
//  Copyright © 2017 Stoiximan Services. All rights reserved.
//

import XCTest
@testable import Nest

class NestTests: XCTestCase {
    
    override func setUp() {
        super.setUp()
        let _ = Nest.shared
    }
    
    
    func testAdd() {
        
        let item = ["item1", "item2"]
        let key = "key"
        
        Nest.shared.add(item: item, withKey: key, expirationPolicy: .short)
        XCTAssert(Nest.shared[key] != nil)
    }
    
    
    func testRemove() {
        
        let item = ["item1", "item2"]
        let key = "key"
        
        Nest.shared.add(item: item, withKey: key, expirationPolicy: .short)
        Nest.shared.removeItem(with: key)
        
        XCTAssert(Nest.shared[key] == nil)
    }
    
    
    func testItemExpiration() {
        
        let item = ["item1", "item2"]
        let key = "importantObject"
        Nest.shared.add(item: item, withKey: key, expirationPolicy: .custom(2))
        
        let expectation = self.expectation(description: "wating for item to expire")
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
            
            XCTAssert(Nest.shared[key] == nil)
            expectation.fulfill()
        }
        
        self.waitForExpectations(timeout: 5)
    }
    
    
    func testOwnerRemove() {
        
        let owner = "name_of_object"
        
        let key1 = Nest.key(with: owner, parameters: ["key1"])
        let key2 = Nest.key(with: owner, parameters: ["key2"])
        
        
        let item1 = ["item1", "item2"]
        Nest.shared.add(item: item1, withKey: key1, expirationPolicy: .short)
        
        let item2 = ["item1", "item2"]
        Nest.shared.add(item: item2, withKey: key2, expirationPolicy: .short)
        
        Nest.shared.clear(ItemsOf: owner)
        
        XCTAssert(Nest.shared[key1] == nil && Nest.shared[key2] == nil)
    }
    
    
    func testFilePersistance() {
        
        let item = ["item1", "item2"]
        let key = "importantObject"
        Nest.shared.add(item: item, withKey: key, expirationPolicy: .custom(1), andPersistancePolicy: .short)
        
        let expectation = self.expectation(description: "wating for item to expire")
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
            
            XCTAssert(Nest.shared[key] != nil)
            expectation.fulfill()
        }
        
        self.waitForExpectations(timeout: 5)
    }
    
    
    func testMirrorPersistancePolicy() {
        
        let item = ["item1", "item2"]
        let key = "importantObject"
        Nest.shared.add(item: item, withKey: key, expirationPolicy: .custom(2), andPersistancePolicy: .mirror)
        
        let expectation = self.expectation(description: "wating for item to expire")
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
            
            XCTAssert(Nest.shared[key] == nil)
            expectation.fulfill()
        }
        
        self.waitForExpectations(timeout: 5)
    }

    
    
    func testConcurentAccess() {
        
        let item = ["item1", "item2"]
        let key = "importantObject"
        
        Nest.shared.add(item: item, withKey: key, expirationPolicy: .custom(2))
        
        let operation = BlockOperation()
        
        operation.addExecutionBlock {
            
            Nest.shared.removeItem(with: key)
        }
        
        var cachedItem: [String]?
        
        operation.addExecutionBlock {
            
            cachedItem = Nest.shared[key] as? [String]
        }
        
        operation.start()
        
        XCTAssert(cachedItem! == item && Nest.shared[key] == nil)
    }
    
    
    func testAddPerformance() {
        
        let item = ["item1", "item2"]
        let key = "importantObject"
        
        measure {
        
            Nest.shared.add(item: item, withKey: key, expirationPolicy: .custom(2))
        }
    }
    
    
    func testPersistancePerformance() {
        
        let item = ["item1", "item2"]
        let key = "importantObject"
        
        measure {
            
            Nest.shared.add(item: item, withKey: key, expirationPolicy: .custom(2), andPersistancePolicy: .short)
        }
    }
    
    
    func testGetFromDiskPerformance() {
        
        let item = ["item1", "item2"]
        let key = "importantObject"
        
        Nest.shared.add(item: item, withKey: key, expirationPolicy: .custom(1), andPersistancePolicy: .short)
        
        let expectation = self.expectation(description: "wating for item to expire")
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
            
            self.measure {
                
                let _ = Nest.shared[key]
            }
            
            expectation.fulfill()
        }
        
        self.waitForExpectations(timeout: 5)
    }
}
