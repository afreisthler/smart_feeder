//
//  FeederDeviceTableViewCell.swift
//  Feeder1
//
//  Created by Freisthler, Andrew on 7/2/17.
//  Copyright © 2017 Freisthler, Andrew. All rights reserved.
//

import UIKit

class FeederDeviceTableViewCell: UITableViewCell {
    
    //MARK: Properties

    @IBOutlet weak var deviceNameLabel: UILabel!
    @IBOutlet weak var uuidLabel: UILabel!
    
    override func awakeFromNib() {
        super.awakeFromNib()
        // Initialization code
    }
    
    override func setSelected(_ selected: Bool, animated: Bool) {
        super.setSelected(selected, animated: animated)
        
        // Configure the view for the selected state
    }
    
}
