//
//  BaseModel.swift
//  Created by Constantinos Liapis on 30/11/2016.
//

import Foundation

open class BaseModel: NSObject {
    
    open var apiToLocalMap: [String: String]!
    open var localToApiMap: [String: String]!
    open var consctuctorMap: [String: () -> Any]!
    
    fileprivate var mappingsConfigured = false
    
    // MARK: Mapping
    
    fileprivate func configureMappings() {
        
        mappingsConfigured = true
        
        consctuctorMap = propertyConstructorMappings()
        apiToLocalMap = apiToLocalMaping()
        
        localToApiMap = [:]
        
        for (key, value) in apiToLocalMap {
            
            localToApiMap[value] = key
        }
    }
    
    
    open func apiToLocalMaping() -> [String: String] {
        
        return [String: String]()
    }
    
    
    // MARK:- Constructor Mapping
    
    open func propertyConstructorMappings() -> [String: () -> Any] {
        
        return [:]
    }
    
    
    // MARK: Serialization - Deserialization
    
    open func deserialize(_ object: [String: AnyObject]) -> Bool {
        
        if mappingsConfigured == false {
            
            configureMappings()
        }
        
        for (key, value) in object {
            
            guard !value.isEqual(NSNull())  else { continue }
            
            // make sure the local path exists in the mappings
            
            if let localPath = self.apiToLocalMap[key] {
                
                // check if the property has value
                if let objectValue = self.value(forKeyPath: localPath) {
                    
                    // the property has value, now check if its type supports serializing
                    if let deserializedValue = tryDeserialize(objectValue as AnyObject, withRawObject: value, localPath: localPath){
                        
                        setValue(deserializedValue, forKey: localPath)
                    }
                    else {
                        
                        return false
                    }
                }
                else {
                    
                    // the property is nil, so we need to check if the constcuctor map knows how to create a new object for this property
                    if let closure = consctuctorMap[localPath] {
                        
                        // we know how to construct the new object, so go construct it
                        let newObject = closure()
                        
                        // now try to feel it with the data
                        if let deserializedValue = tryDeserialize(newObject as AnyObject, withRawObject: value, localPath: localPath){
                            
                            setValue(deserializedValue, forKey: localPath)
                        }
                        else {
                            
                            return false
                        }
                    }
                    else {
                        
                        // if the constructor map contains no info on how to create a new object, simply set the value
                        setValue(value, forKey: localPath)
                    }
                }
            }
        }
        
        return true
    }
    
    
    
    fileprivate func tryDeserialize(_ property: AnyObject, withRawObject rawObject: AnyObject, localPath: String) -> AnyObject? {
        
        if let objectProperty = property as? BaseModel {
            
            // if its BaseModel, we can deserialize it by the calling the deserialize method of the base class
            
            if let _rawObject = rawObject as? [String: AnyObject] {
                
                let res = objectProperty.deserialize(_rawObject)
                return res ? objectProperty : nil
            }
        }
        else if var arrayProperty = property as? [AnyObject] {
            
            // there are 2 different ways to handle the array
            // 1. the raw object is a full object representation of the array
            // 2. the raw object is an array patch of the array
            
            // if its an array of BaseModels, we now need to check if we know how to construct the elements inside the array
            // to do this we will use the constructors map.
            // Lets assume that the object has a property of type: [BaseModel] and the name of the property is "events"
            // the key to get the constructor for the array is "events" (the same with the property) and the key to invoke the
            // constructor for an element inside the specifit array is: "event."
            
            if let rawArray = rawObject as? [[String: AnyObject]] { // object
                
                arrayProperty.removeAll()
                
                // in this case we only care about objects that we know how to create
                
                if let closure = consctuctorMap[String(format: "%@.", localPath)] {
                    
                    // iterate all the elements of the raw array and constuct the actual objects
                    for rawElement in rawArray {
                        
                        // create the new object
                        let element = closure() as AnyObject
                        
                        // if the created object is a subclass of the BaseModel deserialize it and add it to the array
                        if let baseModelelement =  element as? BaseModel {
                            
                            let res = baseModelelement.deserialize(rawElement)
                            guard res == true else { return nil }
                            
                            arrayProperty.append(baseModelelement)
                        }
                        else {
                            
                            // if its not a BaseModel then just append it to the array
                            arrayProperty.append(element)
                        }
                    }
                    
                    return arrayProperty as AnyObject?
                }
            }
        }
        
        // at this point no special treatment needded for the given property, so just return it as is so that the deserialize method will set it to the
        // property of the object
        return rawObject
    }
    
    open func serialize() -> [String: AnyObject] {
        
        if mappingsConfigured == false {
            
            configureMappings()
        }
        
        var object = [String: AnyObject]()
        
        for (key, value) in localToApiMap {
            
            if let propertyValue = self.value(forKeyPath: key) as? BaseModel {
                
                object[value] = propertyValue.serialize() as AnyObject?
            }
            else if let propertyValue = self.value(forKeyPath: key) as? [BaseModel] {
                
                var array: [AnyObject] = []
                
                for baseModel in propertyValue {
                    
                    let item = baseModel.serialize()
                    array.append(item as AnyObject)
                }
                
                object[value] = array as AnyObject?
            }
            else if let propertyValue = self.value(forKeyPath: key) {
                
                object[value] = propertyValue as AnyObject?
            }
        }
        
        return object
    }
}
    
