//
//  FeederRunEventTableViewCell.swift
//  Feeder1
//
//  Created by Freisthler, Andrew on 5/30/17.
//  Copyright © 2017 Freisthler, Andrew. All rights reserved.
//

import UIKit

class FeederRunEventTableViewCell: UITableViewCell {
    
    //MARK: Properties
    @IBOutlet weak var typeAndTimeLabel: UILabel!
    @IBOutlet weak var runDurationLabel: UILabel!
    @IBOutlet weak var photoImageView: UIImageView!

    override func awakeFromNib() {
        super.awakeFromNib()
        // Initialization code
    }

    override func setSelected(_ selected: Bool, animated: Bool) {
        super.setSelected(selected, animated: animated)

        // Configure the view for the selected state
    }

}
