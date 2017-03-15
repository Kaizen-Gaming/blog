# Nest - Documentation

Nest is an easy to use cache library written in Swift 3.0, compatible with iOS, watchOS, macOS and server side Swift.

## Features
* Swifty syntax
* Thread safe
* File system persistance policies
* No dependency on networking libraries
* No limitation on the type of the cached items
* Cached items can be grouped by owner, for grouped management


### Usage
#### Initialization
Initializes the cache and loads the persisted object containers from the disk. The actual persisted object is stored in a different file and will be loaded only if requested.
```Swift
let _ = Nest.shared
```

#### Add item
Adds an object into the cache
```Swift
let item = ["item1", "item2"]
let key = "key"
        
Nest.shared.add(item: item, withKey: key, expirationPolicy: .short)
```

#### Add - File Persistance
Adds an object into the cache and saves it to disk
```Swift
let item = ["item1", "item2"]
let key = "key"
        
Nest.shared.add(item: item, withKey: key, expirationPolicy: .short, andPersistancePolicy: .short))
```

#### Remove item
Removes an item from the cache. 
If the file has a persistance policy, the file will be removed too.
```Swift
Nest.shared.removeItem(with: key)
```

#### Get item
Fetches an object from cache. 
If, based on the in-memory expiration policy, the object has expired and there is a persistance policy enabled, it will be loaded from disk and the the expiration policy will be reissued.
```Swift
let item = Nest.shared[key]
```

### Expiration Policies
There are 6 different expiration policies to choose from. Each one has a coresponding expiration interval. Of cource these values can be changed to match the business of each application. There is also a policy called custom where the expiration interval is specified explicitely.
```Swift
public enum ExpirationPolicy: RawRepresentable {
    
    case short
    case medium
    case long
    case max
    case never
    case custom(TimeInterval)
}
```

### Persistance Policies
The persistance policy is different from the expiration policy. For example we may choose to cache an image for 2 minutes in memory, but 2 days in the file system. After the memory expiration, the object is removed from the memory but its present in the file system. Persistance policies are available for objects implementing the NSCoding protocol. If the object does not implement the NSCoding protocol, the persistance policy is disabled.

```Swift
public enum PersistancePolicy: RawRepresentable {
    
    case disabled
    case mirror     // mirrors the memory expiratio policy
    case short
    case medium
    case long
}
```

### Key Generator
The key is typically a String. Sometimes some items are related under the same entity. These items may require some grouped management, especially on removal.
For example, in an application we have a User Controller to handle all the tasks related to the authenticated user. We may cache many of this data. When the user signs out, we need to remove all these items from our cache.
But how can we do that? We could keep record of all the keys that the controller is using. It works but it's not efficient. 

Nest has the ability to know the "owner" of each cached item. This info is stored into the key.
Here is an example

```Swift
class UserController {

    let identifier {

        return "UserController"
    }

    func fetchUserData() {

        // fetch the data..
        .....

        // add to cache
        let key = Nest.key(with: identifier, parameters: ["userData", [username]])
        Nest.shared.add(item: userData, withKey: key, expirationPolicy: .short)
    }

    func userDidLogout() {

        Nest.shared.clear(ItemsOf: identifier)
    }
}
```

#### Threads and concurrent access
As mentioned above, this implementation is thread safe. Let's say a few words abount the implementation.
There are two ways to access the cache, to read (get or enumerate) and to write (add or remove). Swift and GCD (Grand Central Dispatch) gives us the tools to avoid the use of locks, at least not in a explicit way. So, all the write access is being driven via a dedicated serial queue, to avoid any race condition. 
```Swift
let queue = DispatchQueue(label: "com.nest.writeQueue")

func syncAdd(_ item: Seed, with key: String) {
        
    queue.sync { storage[key] = item }
}

func syncRemove(itemWith key: String) {
        
    let _ = queue.sync { storage.removeValue(forKey: key) }
}
```
As far as read access is concenred, the value type nature of the Dictionary solves the issue. Before any access or enumeration, a snapshot of the dictionary is being kept in a local variable. This "copy" of the dictionary is now safe to perform any read action.

```Swift
subscript (key: String) -> Any? {
        
    let _storage = storage
    guard let object = _storage[key]?.object else {
            
        syncRemove(itemWith: key)
        return nil
    }
        
    return object
}

open func clear(ItemsOf owner: String? = nil) {
        
    let _storage = storage
        
     _storage.forEach { (key, item) in
         ...
     }
}

```

## Note
For iOS applications whose state (background, foreground) changes quite often, we should make sure to call `Nest.shared.clearExpired()` in the  `UIApplicationDidBecomeActive` event.