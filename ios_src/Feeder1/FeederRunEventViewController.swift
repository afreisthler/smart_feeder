//
//  FeederRunEventViewController.swift
//  Feeder1
//
//  Created by Freisthler, Andrew on 5/30/17.
//  Copyright © 2017 Freisthler, Andrew. All rights reserved.
//

import UIKit
import os.log

class FeederRunEventViewController: UIViewController, UIPickerViewDataSource, UIPickerViewDelegate {

    
    // MARK: - Properties
    
    // All our outlets
    @IBOutlet weak var saveRunEvent: UIBarButtonItem!
    @IBOutlet weak var pickerTextField: UITextField!
    @IBOutlet weak var datepickerTextField: UITextField!
    @IBOutlet weak var durationTextField: UITextField!
    @IBOutlet weak var offsetTextField: UITextField!
    
    // List of options for our type picker
    var typeOptions = ["Sunrise", "Set Time", "Sunset"]
    
    // Passed by table for edit or created during new creation
    var feederRunEvent: FeederRunEvent?
    
    // We will hold the datetime in a seprate var so it is easy to set a default.  Set to today at 9AM
    var localDate = Date()
    
    
    // MARK: - Public Methods
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Allow closing of pickers/keyboard with touches outside that area
        let tap: UITapGestureRecognizer = UITapGestureRecognizer(target: self, action: #selector(FeederRunEventViewController.dismissKeyboard))
        view.addGestureRecognizer(tap)
        
        // Create picker for type
        let pickerView = UIPickerView()
        pickerView.delegate = self
        pickerTextField.inputView = pickerView
        
        // Create picker for time
        let datePickerView:UIDatePicker = UIDatePicker()
        datePickerView.datePickerMode = UIDatePickerMode.time
        datepickerTextField.inputView = datePickerView
        datePickerView.addTarget(self, action: #selector(FeederRunEventViewController.datePickerValueChanged), for: UIControlEvents.valueChanged)
        
        // If we were passed an item then we are editing.  Will update UI here to reflect differences
        if feederRunEvent != nil {
            navigationItem.title = "Edit Run Event"
            updateAllFields()
            
        } else {
            // fix up local date to be 9AM
            let today = Date()
            localDate = Calendar.current.date(bySettingHour: 9, minute: 0, second: 0, of: today)!
        }
        
        // Set time value into text field
        updateTimeTextField()
        
        // Set date on picker to either default or value passed so it matches text field.
        datePickerView.date = localDate
        
        // Enable negative sign on keyboard
        addMinusButtonToNumpadForOffset()
    }
    

    // MARK: - Type Picker
    
    func numberOfComponents(in: UIPickerView) -> Int {
        return 1
    }
    
    func pickerView(_ pickerView: UIPickerView, numberOfRowsInComponent component: Int) -> Int {
        return typeOptions.count
    }
    
    func pickerView(_ pickerView: UIPickerView, titleForRow row: Int, forComponent component: Int) -> String? {
        return typeOptions[row]
    }
    
    func pickerView(_ pickerView: UIPickerView, didSelectRow row: Int, inComponent component: Int) {
        pickerTextField.text = typeOptions[row]
    }
    
    
    // MARK: - Date Picker
    
    func datePickerValueChanged(sender:UIDatePicker) {
        localDate = sender.date
        updateTimeTextField()
    }
    
    
    // MARK: - Navigation
    
    @IBAction func cancel(_ sender: UIBarButtonItem) {
        
        
        let isPresentingInAddMode = presentingViewController is UINavigationController
        
        if isPresentingInAddMode {
            dismiss(animated: true, completion: nil)
        } else if let owningNavigationController = navigationController {
            owningNavigationController.popViewController(animated: true)
        } else {
            fatalError("The ViewController is not inside a navigation controller as expected")
        }
    }
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        super.prepare(for: segue, sender: sender)
        
        // This block will execute if a user hit Cancel
        guard let button = sender as? UIBarButtonItem, button === saveRunEvent else {
            os_log("The save button was not pressed, cancelling", log: OSLog.default, type: .debug)
            return
        }
        
        // todo: error handling on fields like nil, decimials, etc.
        
        // We will fall to here if saving or adding
        let date = localDate
        let type = pickerTextField.text
        let offset = Int(offsetTextField.text!)
        let runMinutes = Int(durationTextField.text!)
        
        // set local var to pass back on unwind segue
        feederRunEvent = FeederRunEvent(type: type!, photo: nil, date: date, offset: offset!, runMinutes: runMinutes!)
    }
    
    
    // MARK: - Private Methods
    
    func dismissKeyboard() {
        view.endEditing(true)
    }
    
    func updateAllFields() {
        offsetTextField.text = String(feederRunEvent!.offset)
        durationTextField.text = String(feederRunEvent!.runMinutes)
        pickerTextField.text = feederRunEvent!.type
        localDate = (feederRunEvent?.date)!
        updateTimeTextField()
    }
    
    func updateTimeTextField() {
        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = DateFormatter.Style.none
        dateFormatter.timeStyle = DateFormatter.Style.short
        datepickerTextField.text = dateFormatter.string(from: localDate)
    }
    
    // The following functions add a negative sign to num pad and handle usage.
    func addMinusButtonToNumpadForOffset(){
        let toolbar = UIToolbar(frame: CGRect(x: 0, y: 0, width: self.view.bounds.size.width, height: 44))
        let minusButton = UIBarButtonItem(title: "-", style: .plain, target: self, action: #selector(toggleMinusOffset))
        toolbar.items = [minusButton]
        offsetTextField.inputAccessoryView = toolbar
    }
    
    func toggleMinusOffset(){
        if var text = offsetTextField.text , text.isEmpty == false{
            if text.hasPrefix("-") {
                text = text.replacingOccurrences(of: "-", with: "")
            } else {
                text = "-\(text)"
            }
            offsetTextField.text = text
        }
    }

}
