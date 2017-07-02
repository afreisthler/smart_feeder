//
//  FeederRunEventTableViewController.swift
//  Feeder1
//
//  Created by Freisthler, Andrew on 5/30/17.
//  Copyright © 2017 Freisthler, Andrew. All rights reserved.
//

import UIKit
import os.log

class FeederRunEventTableViewController: UITableViewController {
    
    // MARK: - Properties
    
    var feederRunEvents = [FeederRunEvent]()
    
    
    
    // MARK: - Actions
    
    @IBAction func unwindToRunEventList(sender: UIStoryboardSegue) {
        
        if let sourceViewController = sender.source as? FeederRunEventViewController, let feederRunEvent = sourceViewController.feederRunEvent {
            
            if let selectedIndexPath = tableView.indexPathForSelectedRow {
                feederRunEvents[selectedIndexPath.row] = feederRunEvent
                tableView.reloadRows(at: [selectedIndexPath], with: .none)
            } else {
                let newIndexPath = IndexPath(row: feederRunEvents.count, section: 0)
                feederRunEvents.append(feederRunEvent)
                tableView.insertRows(at: [newIndexPath], with: .automatic)
            }
            
            saveFeederRunEvents()
            
        }
        
    }
    
    
    // MARK: - Public Methods
    
    override func viewDidLoad() {
        super.viewDidLoad()

        // for testing
        
        if let savedFeederRunEvents = loadFeederRunEvents() {
            feederRunEvents += savedFeederRunEvents
            
        } else {
            loadSampleFeederRunEvents()
        }

    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }

    
    // MARK: - Table View Methods

    override func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return feederRunEvents.count
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        
        let cellIdentifier = "FeederRunEventTableViewCell"
        
        guard let cell = tableView.dequeueReusableCell(withIdentifier: cellIdentifier, for: indexPath) as? FeederRunEventTableViewCell else {
            fatalError("The dequeued cell is not the correc instance")
        }

        let feederRunEvent = feederRunEvents[indexPath.row]
        
        if feederRunEvent.type == "Sunrise" || feederRunEvent.type == "Sunset" {
            if feederRunEvent.offset >= 0 {
                cell.typeAndTimeLabel.text = feederRunEvent.type + " +" + String(feederRunEvent.offset) + " Minutes"
            } else {
                cell.typeAndTimeLabel.text = feederRunEvent.type + " " + String(feederRunEvent.offset) + " Minutes"
            }
        } else {
            let dateFormatter = DateFormatter()
            dateFormatter.dateStyle = DateFormatter.Style.none
            dateFormatter.timeStyle = DateFormatter.Style.short
            cell.typeAndTimeLabel.text = feederRunEvent.type + " " + dateFormatter.string(from: feederRunEvent.date)
        }
        cell.runDurationLabel.text = String(feederRunEvent.runMinutes) + " Second Feeding"


        return cell
    }

    override func tableView(_ tableView: UITableView, canEditRowAt indexPath: IndexPath) -> Bool {
        return true
    }
    
    override func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCellEditingStyle, forRowAt indexPath: IndexPath) {
        if editingStyle == .delete {
            // Delete the row from the data source
            feederRunEvents.remove(at: indexPath.row)
            saveFeederRunEvents()
            tableView.deleteRows(at: [indexPath], with: .fade)
        } else if editingStyle == .insert {
            // Create a new instance of the appropriate class, insert it into the array, and add a new row to the table view
        }    
    }
    

    // MARK: - Navigation

    // In a storyboard-based application, you will often want to do a little preparation before navigation
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        super.prepare(for: segue, sender: sender)
        
        switch(segue.identifier ?? "") {
            
        case "addItem":
            os_log("Adding a feeder run event.", log: OSLog.default, type: .debug)
            
        case "showDetail":
            os_log("Editing a feeder run event.", log: OSLog.default, type: .debug)
            let feederRunEventDetailViewController = segue.destination as? FeederRunEventViewController
            let selectedFeederRunEventCell = sender as? FeederRunEventTableViewCell
            let indexPath = tableView.indexPath(for: selectedFeederRunEventCell!)
            let selectedFeederRunEvent = feederRunEvents[(indexPath?.row)!]
            feederRunEventDetailViewController?.feederRunEvent = selectedFeederRunEvent
            
        default:
            fatalError("Unexpected Segue Identifier; \(String(describing: segue.identifier))")
        }
        
    }

    
    private func loadSampleFeederRunEvents() {
        let date = Date()
        
        let feederRunEvent1 = FeederRunEvent(type: "Sunrise", photo: nil, date: date, offset: 30, runMinutes: 2)
        let feederRunEvent2 = FeederRunEvent(type: "Sunset", photo: nil, date: date, offset: -30, runMinutes: 2)
        
        feederRunEvents += [feederRunEvent1, feederRunEvent2]
        
    }
    
    // MARK: - Private Methods
    
    private func saveFeederRunEvents() {
        let isSuccessfulSave = NSKeyedArchiver.archiveRootObject(feederRunEvents, toFile: FeederRunEvent.ArchiveURL.path)
        if isSuccessfulSave {
            os_log("List of run events save success", log: OSLog.default, type: .debug)
        } else {
            os_log("List of run events save failure", log: OSLog.default, type: .error)
        }
    }
    
    private func loadFeederRunEvents() -> [FeederRunEvent]? {
        return NSKeyedUnarchiver.unarchiveObject(withFile: FeederRunEvent.ArchiveURL.path) as? [FeederRunEvent]
    }
    

}
