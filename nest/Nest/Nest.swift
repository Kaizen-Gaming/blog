//
//  Nest
//  Stoiximan
//
//  Created by Cliapis on 20/12/2016.
//  Copyright © 2016 Stoiximan Services. All rights reserved.
//

import Foundation

public enum ExpirationPolicy: RawRepresentable {
    
    case short
    case medium
    case long
    case max
    case never
    case custom(TimeInterval)
    
    var interval: TimeInterval {
        
        switch self {
        case .short:                    return 60.0
        case .medium:                   return 300.0
        case .long:                     return 600.0
        case .max:                      return 900.0
        case .never:                    return Date.distantFuture.timeIntervalSinceNow
        case .custom(let interval):     return interval
        }
    }
    
    public var rawValue: String {
        
        switch self {
        case .short:                    return "short"
        case .medium:                   return "medium"
        case .long:                     return "long"
        case .max:                      return "max"
        case .never:                    return "never"
        case .custom(let interval):     return "custom:\(interval)"
        }
    }
    
    
    public init?(rawValue: String) {
        
        switch rawValue {
            
        case "short":   self =  .short
        case "medium":  self =  .medium
        case "long":    self =  .long
        case "max":     self =  .max
    	case "never":   self =  .never
        default:
            
            guard rawValue.hasPrefix("custom:"),
                let interval = TimeInterval(rawValue.substring(from: rawValue.index(rawValue.startIndex, offsetBy: 7))) else {  return nil }
            
            self = .custom(interval)
        }
    }
}


public enum PersistancePolicy: RawRepresentable {
    
    case disabled
    case mirror
    case short
    case medium
    case long
    
    var interval: TimeInterval {
        
        switch self {
        case .disabled:                 return 0
        case .mirror:                   return 0
        case .short:                    return 86400
        case .medium:                   return 259200
        case .long:                     return 864000
        }
    }
    
    public var rawValue: String {
        
        switch self {
        case .disabled:                 return "disabled"
        case .mirror:                   return "mirror"
        case .short:                    return "short"
        case .medium:                   return "medium"
        case .long:                     return "long"
        }
    }
    
    
    public init?(rawValue: String) {
        
        switch rawValue {
        case "disabled":    self = .disabled
        case "mirror" :     self = .mirror
        case "short" :      self = .short
        case "medium" :     self = .medium
        case "long" :       self = .long
        default:            return nil
            
        }
    }
}


// MARK:- CacheItem

fileprivate class Seed: NSObject, NSCoding {
    
    var key: String
    
    var _object: Any?
    var object: Any? {
        
        if let object = _object { return object }
        
        if let filename = filename {
            
            guard let documentsURL = Nest.documentsURL() else { return  _object }
            let fileURL = documentsURL.appendingPathComponent(filename)
            
            if let object = NSKeyedUnarchiver.unarchiveObject(withFile: fileURL.path) {
                
                _object = object
                setExpirationDates()
            }
        }
        
        return _object
    }
    
    var expirationPolicy: ExpirationPolicy
    var persistancePolicy: PersistancePolicy
    
    var expirationDate: Date?
    var persistanceExpirationDate: Date?
    var filename: String?
    
    init(key: String, object: Any?, expirationPolicy: ExpirationPolicy, persistancePolicy: PersistancePolicy, filename: String?) {
        
        self.key = key
        self._object = object
        self.expirationPolicy = expirationPolicy
        self.persistancePolicy = persistancePolicy
        self.filename = filename
        
        expirationDate = Date().addingTimeInterval(expirationPolicy.interval)
        
        if persistancePolicy.interval != 0 {
            
            persistanceExpirationDate = Date().addingTimeInterval(persistancePolicy.interval)
        }
    }
    
    
    // MARK: NSCoding Protocol
    
    required init?(coder aDecoder: NSCoder) {
        
        guard let key = aDecoder.decodeObject(forKey: "key") as? String,
            let rawExpirationPolicy = aDecoder.decodeObject(forKey: "expirationPolicy") as? String,
            let expirationPolicy = ExpirationPolicy(rawValue: rawExpirationPolicy),
            let rawPersistancePolicy = aDecoder.decodeObject(forKey: "persistancePolicy") as? String,
            let persistancePolicy = PersistancePolicy(rawValue: rawPersistancePolicy)
            else { return nil }
        
        self.key = key
        self.expirationPolicy = expirationPolicy
        self.persistancePolicy = persistancePolicy
        
        if persistancePolicy.interval != 0 {
            
            persistanceExpirationDate = Date().addingTimeInterval(persistancePolicy.interval)
        }
        
        if let filename = aDecoder.decodeObject(forKey: "filename") as? String {
        
            self.filename = filename
        }
    }
    
    
    internal func encode(with aCoder: NSCoder) {
        
        aCoder.encode(key, forKey: "key")
        aCoder.encode(expirationPolicy.rawValue, forKey: "expirationPolicy")
        aCoder.encode(persistancePolicy.rawValue, forKey: "persistancePolicy")
        if let filename = filename {
        
            aCoder.encode(filename, forKey: "filename")
        }
    }
    
    
    open func invalidateObject() {
        
        _object = nil
    }
    
    
    // MARK: Expiration Policy Setup
    
    fileprivate func setExpirationDates() {
        
        expirationDate = Date().addingTimeInterval(expirationPolicy.interval)
        
        if persistancePolicy.interval != 0 {
            
            persistanceExpirationDate = Date().addingTimeInterval(persistancePolicy.interval)
        }
    }
}



// MARK:- Cache

fileprivate let indexFilename = "NestContents"

open class Nest: NSObject {
    
    static let shared = Nest()
    fileprivate var storage: [String: Seed] = [:]
    
    fileprivate let queue = DispatchQueue(label: "com.nest.writeQueue")
    
    //fileprivate queue:

    subscript (key: String) -> Any? {
        
        let _storage = storage
        guard let object = _storage[key]?.object else {
            
            syncRemove(itemWith: key)
            return nil
        }
        
        return object
    }
    
    
    
    // MARK: Init
    
    override init() {
        
        super.init()
        load()
    }
    
    
    // MARK: Add
    
    open func add(item: Any, withKey key: String, expirationPolicy policy: ExpirationPolicy, andPersistancePolicy persistPolicy: PersistancePolicy = .disabled) {
        
        var filename: String? = nil
        
        var resolvedPersistPolicy = persistPolicy
        
        if persistPolicy != .disabled, item is NSCopying, let documentsURL = Nest.documentsURL() {
            
            let uuid = UUID().uuidString
            filename = uuid
            let fileURL = documentsURL.appendingPathComponent(uuid)
            
            if NSKeyedArchiver.archiveRootObject(item, toFile: fileURL.path) == false {
                
                resolvedPersistPolicy = .disabled
                filename = nil
            }
        }
        else {
            
            resolvedPersistPolicy = .disabled
        }
        
        let item = Seed(key: key, object: item, expirationPolicy: policy, persistancePolicy: resolvedPersistPolicy, filename: filename)
        syncAdd(item, with: key)
        
        if resolvedPersistPolicy != .disabled {
         
            persist()
        }
        
        Timer.scheduledTimer(timeInterval: policy.interval, target: self, selector: #selector(self.expirationTimer(timer:)),
                             userInfo: key, repeats: false)
    }
    
    
    fileprivate func syncAdd(_ item: Seed, with key: String) {
        
        queue.sync { storage[key] = item }
    }
    
    
    // MARK: Remove
    
    open func removeItem(with key: String) {
        
        let _storage = storage
        guard let item = _storage[key] else { return }
        var needsPersistance = false
        
        NSLog("removing from cache key: %@", key)
        
        if item.persistancePolicy != .disabled {
            
            needsPersistance = true
            
            DispatchQueue.global(qos: DispatchQoS.QoSClass.background).async { () -> Void in
                
                do {
                    
                    if let documentsURL = Nest.documentsURL(), let filename = item.filename {
                        
                        let fileURL = documentsURL.appendingPathComponent(filename)
                        try FileManager.default.removeItem(at: fileURL)
                    }
                }
                catch {}
            }
        }
        
        syncRemove(itemWith: key)
        if needsPersistance {
            
            persist()
        }
    }
    
    
    fileprivate func syncRemove(itemWith key: String) {
        
        let _ = queue.sync { storage.removeValue(forKey: key) }
    }
    
    
    // MARK: Expiration
    
    internal func expirationTimer(timer: Timer) {
        
        let _storage = storage
        guard let key = timer.userInfo as? String, let item = _storage[key] else { return }
        
        NSLog("item with key: %@, expired", key)
        
        if item.persistancePolicy == .disabled || item.persistancePolicy == .mirror {
            
            removeItem(with: key)
        }
        else {
            
            item.invalidateObject()
        }
    }
    
    
    // MARK: Clear
    
    open func clear(ItemsOf owner: String? = nil) {
        
        guard let owner = owner else {
            
            storage.removeAll()
            return
        }
        
        var keysToClear = [String]()
        var needsPersistance = false
        
        let _storage = storage
        
        _storage.forEach { (key, item) in
            
            if item.persistancePolicy != .disabled {
                
                needsPersistance = true
            }
            
            if key.hasPrefix(owner) {
                
                keysToClear.append(key)
            }
        }
        
        for key in keysToClear {
            
            removeItem(with: key)
        }
        
        if needsPersistance {
            
            persist()
        }
    }
    
    
    open func clearExpired() {
        
        var keysToRemove = [String]()
        let now = Date()
        
        let _storage = storage
        
        _storage.forEach { (key, item) in
            
            if let expirationDate = item.expirationDate {
                
                if expirationDate < now {
                    
                    keysToRemove.append(key)
                }
            }
        }
        
        keysToRemove.forEach { (key) in
            
            removeItem(with: key)
        }
    }
    
    
    // MARK: Persistance
    
    fileprivate func persist() {
        
        var persistableContent = [Seed]()
        
        let _storage = storage
        
        _storage.forEach { (_, item) in
            
            if item.persistancePolicy != .disabled {
                
                persistableContent.append(item)
            }
        }
        
        DispatchQueue.global(qos: DispatchQoS.QoSClass.background).async { () -> Void in
            
            let _ = NSKeyedArchiver.archiveRootObject(persistableContent, toFile: Nest.indexFilePath())
        }
    }
    
    
    fileprivate func load() {
        
        var expiredItems = [String]()
        
        if let archivedContents = NSKeyedUnarchiver.unarchiveObject(withFile: Nest.indexFilePath()) as? [Seed] {
            
            let now = Date()
            
            archivedContents.forEach({ (item) in
                
                if let expirationDate = item.persistanceExpirationDate, expirationDate > now {
                 
                    storage[item.key] = item
                }
                else if let filename = item.filename {
                    
                    expiredItems.append(filename)
                }
            })
        }
        
        if let documentsURL = Nest.documentsURL(), expiredItems.count > 0 {
            
            expiredItems.forEach({ (filename) in
                
                let fileURL = documentsURL.appendingPathComponent(filename)
                do { try FileManager.default.removeItem(at: fileURL) }
                catch {}
            })
            
            expiredItems.removeAll()
        }
    }
    
    
    // MARK: Keys
    
    open class func key(with owner: String, parameters: [String]) -> String {
        
        return "\(owner)-\(parameters.joined(separator: "|"))"
    }
    
    
    // MARK: Convenience Methods
    
    fileprivate class func documentsURL() -> URL? {
        
        return FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first
    }
    
    
    fileprivate class func indexFilePath() -> String {
        
        guard let documentsURL = Nest.documentsURL() else {
        
            return indexFilename
        }
        
        let fileURL = documentsURL.appendingPathComponent(indexFilename)
        return fileURL.path
    }
}
