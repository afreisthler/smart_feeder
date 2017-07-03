//
//  FeederRunEvent.swift
//  Feeder1
//
//  Created by Freisthler, Andrew on 5/30/17.
//  Copyright © 2017 Freisthler, Andrew. All rights reserved.
//

import UIKit
import os.log


// Sublassing NSObject and NSCoding so we can easily persist data
class FeederRunEvent: NSObject, NSCoding {
    
    
    // MARK: - Properties
    
    var type: String
    var photo: UIImage?
    var date: Date
    var offset: Int
    var runMinutes: Int
    
    
    // MARK: - Archiving Paths
    
    static let DocumentsDirectory = FileManager().urls(for: .documentDirectory, in: .userDomainMask).first!

    
    // MARK: - Types
    
    struct PropertyKey {
        static let type = "type"
        static let photo = "photo"
        static let date = "date"
        static let offset = "offset"
        static let runMinutes = "runMinutes"
    }
    
    
    // MARK: - Initialization
    
    init(type: String, photo: UIImage?, date: Date, offset: Int, runMinutes: Int) {
        self.type = type
        self.photo = photo
        self.date = date
        self.offset = offset
        self.runMinutes = runMinutes
    }
    
    
    // MARK: - NSCoding
    
    func encode(with aCoder: NSCoder) {
        aCoder.encode(type, forKey: PropertyKey.type)
        aCoder.encode(photo, forKey: PropertyKey.photo)
        aCoder.encode(date, forKey: PropertyKey.date)
        aCoder.encode(offset, forKey: PropertyKey.offset)
        aCoder.encode(runMinutes, forKey: PropertyKey.runMinutes)
    }
    
    
    required convenience init?(coder aDecoder: NSCoder) {
        let type = aDecoder.decodeObject(forKey: PropertyKey.type) as? String
        let photo = aDecoder.decodeObject(forKey: PropertyKey.photo) as? UIImage
        let date = aDecoder.decodeObject(forKey: PropertyKey.date) as? Date
        let offset = aDecoder.decodeInteger(forKey: PropertyKey.offset)
        let runMinutes = aDecoder.decodeInteger(forKey: PropertyKey.runMinutes)
        self.init(type: type!, photo: photo, date: date!, offset: offset, runMinutes: runMinutes)
    }
    
}
