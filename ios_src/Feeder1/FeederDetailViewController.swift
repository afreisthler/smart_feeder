//
//  FeederDetailViewController.swift
//  Feeder1
//
//  Created by Freisthler, Andrew on 5/17/17.
//  Copyright © 2017 Freisthler, Andrew. All rights reserved.
//

import UIKit
import os.log
import CoreBluetooth
import CoreLocation

class FeederDetailViewController: UIViewController, CBCentralManagerDelegate, CBPeripheralDelegate, CLLocationManagerDelegate {
    
    
    // MARK: - Properties
    
    var centralManager:CBCentralManager!
    var feeder:CBPeripheral?
    var transmitCharacteristic:CBCharacteristic? = nil
    
    // Define Advertising name and UUIDs for AdaFruit BLE Device.  See documentation here:
    //    https://learn.adafruit.com/introducing-adafruit-ble-bluetooth-low-energy-friend/uart-service
    
    let feederAdvertiseName = "Adafruit Bluefruit LE"
    let BLEUartService = "6E400001-B5A3-F393-E0A9-E50E24DCCA9E"
    let BLEUartTxCharacteristic = "6E400002-B5A3-F393-E0A9-E50E24DCCA9E"
    let BLEUartRxCharacteristic = "6E400003-B5A3-F393-E0A9-E50E24DCCA9E"
    
    let BLESpecificPeripheralUUID = "BC20DB14-B33B-4A99-A202-55F3F5BAC384"
    
    // Useful for some sleep calculations
    let ms = 1000
    var timer: Timer?
    
    // Outlets
    @IBOutlet weak var voltageLabel: UILabel!
    @IBOutlet weak var timeLabel: UILabel!
    @IBOutlet weak var nextRunLabel: UILabel!
    @IBOutlet weak var durationLabel: UILabel!
    @IBOutlet weak var editButton: UIButton!
    @IBOutlet weak var synchButton: UIButton!
    @IBOutlet weak var feedNowButon: UIButton!
    
    // Var to know whether or not we should be communicating
    var feederConnected = false
    var forceDisconnect = false
    
    // Activity monitor when needed while processing
    var activityIndicator:UIActivityIndicatorView = UIActivityIndicatorView()


    
    // Location data
    let locationManager = CLLocationManager()
    var latitude = 0.0
    var longitude = 0.0
    var haveSetDeviceLocation = false
    
    // MARK: - Public Methods
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Let reconnects to occur
        forceDisconnect = false

        // Set up activity indicator
        activityIndicator.center = self.view.center
        activityIndicator.hidesWhenStopped = true
        activityIndicator.activityIndicatorViewStyle = UIActivityIndicatorViewStyle.gray
        view.addSubview(activityIndicator)
        
        // BLE Initialization
        centralManager = CBCentralManager(delegate: self, queue: nil)
        
        // Location Initialization
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
        locationManager.requestWhenInUseAuthorization()
        locationManager.startUpdatingLocation()
        
        // Let reconnects to occur
        forceDisconnect = false
        
    }


    // MARK: - Actions

    // Feed Now Button
    @IBAction func executeAction(_ sender: UIButton) {
        os_log("Eecuting Run Now", log: OSLog.default, type: .debug)
        sendToDevice(command: "ru", buffer: "")
    }
    
    
    // Sync Button
    @IBAction func synchDevice(_ sender: UIButton) {
        

        os_log("Eecuting Sync Device", log: OSLog.default, type: .debug)
        
        disableAllButtons()
        activityIndicator.startAnimating()
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            
            if let savedFeederRunEvents = self.loadFeederRunEvents() {
                if savedFeederRunEvents.count > 0 {
                    self.sendToDevice(command: "cl" + String(savedFeederRunEvents.count), buffer: "")
                    for i in 0...savedFeederRunEvents.count-1 {
                        self.sendToDevice(command: "ty" + String(i), buffer: savedFeederRunEvents[i].type)
                        self.sendToDevice(command: "rm" + String(i), buffer: String(savedFeederRunEvents[i].runMinutes))
                        self.sendToDevice(command: "of" + String(i), buffer: String(savedFeederRunEvents[i].offset))
                        self.sendToDevice(command: "da" + String(i), buffer: String(savedFeederRunEvents[i].date.timeIntervalSince1970))
                    }
                    self.sendToDevice(command: "rc", buffer: "")
                }
            }

            self.activityIndicator.stopAnimating()
            self.enableAllButtons()
        }
    }
    
    
    // MARK: - CBCentralManagerDelegate methods
    
    // Invoked when the central manager’s state is updated.
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        var showAlert = true
        var message = ""
        
        switch central.state {
        case .poweredOff:
            message = "Bluetooth on this device is currently powered off."
        case .unsupported:
            message = "This device does not support Bluetooth Low Energy."
        case .unauthorized:
            message = "This app is not authorized to use Bluetooth Low Energy."
        case .resetting:
            message = "The BLE Manager is resetting; a state update is pending."
        case .unknown:
            message = "The state of the BLE Manager is unknown."
        case .poweredOn:
            showAlert = false
            os_log("BLE on and ready.  Scanning for feeder.", log: OSLog.default, type: .debug)
            centralManager.scanForPeripherals(withServices: [CBUUID(string: BLEUartService)], options: nil)
        }
        
        if showAlert {
            let alertController = UIAlertController(title: "Central Manager State", message: message, preferredStyle: UIAlertControllerStyle.alert)
            let okAction = UIAlertAction(title: "OK", style: UIAlertActionStyle.cancel, handler: nil)
            alertController.addAction(okAction)
            self.show(alertController, sender: self)
        }
    }
    
    
    /*
     Invoked when the central manager discovers a peripheral while scanning.
     
     The advertisement data can be accessed through the keys listed in Advertisement Data Retrieval Keys.
     You must retain a local copy of the peripheral if any command is to be performed on it.
     In use cases where it makes sense for your app to automatically connect to a peripheral that is
     located within a certain range, you can use RSSI data to determine the proximity of a discovered
     peripheral device.
     
     central - The central manager providing the update.
     peripheral - The discovered peripheral.
     advertisementData - A dictionary containing any advertisement data.
     RSSI - The current received signal strength indicator (RSSI) of the peripheral, in decibels.
     */
    func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral, advertisementData: [String : Any], rssi RSSI: NSNumber) {
        
        if let peripheralName = advertisementData[CBAdvertisementDataLocalNameKey] as? String {
            
            // Connect if it exact right device
            if peripheralName == feederAdvertiseName && peripheral.identifier.uuidString == BLESpecificPeripheralUUID {
                os_log("Connecting to feeder", log: OSLog.default, type: .debug)
                feeder = peripheral
                feeder!.delegate = self
                centralManager.connect(feeder!, options: nil)
            }
        }
    }
    
    
    /*
     Invoked when a connection is successfully created with a peripheral.
     
     This method is invoked when a call to connectPeripheral:options: is successful.
     You typically implement this method to set the peripheral’s delegate and to discover its services.
     */
    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        os_log("Connected to feeder", log: OSLog.default, type: .debug)
        peripheral.discoverServices(nil)
        feederConnected = true
    }
    
    
    /*
     Invoked when the central manager fails to create a connection with a peripheral.
     This method is invoked when a connection initiated via the connectPeripheral:options: method fails to complete.
     Because connection attempts do not time out, a failed connection usually indicates a transient issue,
     in which case you may attempt to connect to the peripheral again.
     */
    func centralManager(_ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral, error: Error?) {
        os_log("Failed to connect to feeder", log: OSLog.default, type: .debug)
    }
    
    
    /*
     Invoked when an existing connection with a peripheral is torn down.
     
     This method is invoked when a peripheral connected via the connectPeripheral:options: method is disconnected.
     If the disconnection was not initiated by cancelPeripheralConnection:, the cause is detailed in error.
     After this method is called, no more methods are invoked on the peripheral device’s CBPeripheralDelegate object.
     
     Note that when a peripheral is disconnected, all of its services, characteristics, and characteristic descriptors are invalidated.
     */
    func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
        os_log("Disconnected from feeder", log: OSLog.default, type: .debug)
        feederConnected = false
        haveSetDeviceLocation = false
        voltageLabel.text = "Unknown"
        timeLabel.text = "Unknown"
        nextRunLabel.text = "Unknown"
        durationLabel.text = "Unknown"
        
        if (!forceDisconnect) {
            // Tell user the connection was lost.
            let alert = UIAlertController(title: "Disconnected", message: "Connection to the Smart Feeder has been lost.  The connection will try to be reestablished.", preferredStyle: UIAlertControllerStyle.alert)
            alert.addAction(UIAlertAction(title: "Ok", style: UIAlertActionStyle.default, handler: nil))
            self.present(alert, animated: true, completion: nil)
        
        centralManager.scanForPeripherals(withServices: [CBUUID(string: BLEUartService)], options: nil)
        }
    }
    
    
    //MARK: - CBPeripheralDelegate methods
    
    /*
     Invoked when you discover the peripheral’s available services.
     
     This method is invoked when your app calls the discoverServices: method.
     If the services of the peripheral are successfully discovered, you can access them
     through the peripheral’s services property.
     
     If successful, the error parameter is nil.
     If unsuccessful, the error parameter returns the cause of the failure.
     */
    // When the specified services are discovered, the peripheral calls the peripheral:didDiscoverServices: method of its delegate object.
    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        if error != nil {
            os_log("Error reported discovering services", log: OSLog.default, type: .debug)
            return
        }
        
        // Scan for the UART Service we will use.  When we find it, call method to discover characteristics.
        if let services = peripheral.services {
            for service in services {
                if (service.uuid.uuidString == BLEUartService) {
                    os_log("Found UART Service", log: OSLog.default, type: .debug)
                    peripheral.discoverCharacteristics(nil, for: service)
                }
            }
        }
    }
    
    
    /*
     Invoked when you discover the characteristics of a specified service.
     
     If the characteristics of the specified service are successfully discovered, you can access
     them through the service's characteristics property.
     
     If successful, the error parameter is nil.
     If unsuccessful, the error parameter returns the cause of the failure.
     */
    func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        
        if error != nil {
            os_log("Error reported discovering characteristics", log: OSLog.default, type: .debug)
            return
        }
        
        // Scan for the TX and RX characteristics we need from the UART Service.  Save reference to the TX characteristic as we'll need 
        //   it to send data.  For recieve, set notifications to true so we recieve transmissions.  Set the clock on device to current time.
        if (service.uuid.uuidString == BLEUartService) {
            for characteristic in service.characteristics! {
                if (characteristic.uuid.uuidString == BLEUartTxCharacteristic) {
                    os_log("Found TX characteristic", log: OSLog.default, type: .debug)
                    transmitCharacteristic = characteristic
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        self.setTimeOnDevice()
                    }
                    usleep(useconds_t(10 * ms))
//                    getAndSetTimeAndVoltage()
                } else if (characteristic.uuid.uuidString == BLEUartRxCharacteristic) {
                    os_log("Found RX characteristic", log: OSLog.default, type: .debug)
                    peripheral.setNotifyValue(true, for: characteristic)
                }
                
            }
            
        }
    }
    
    
    /*
     Invoked when you retrieve a specified characteristic’s value,
     or when the peripheral device notifies your app that the characteristic’s value has changed.
     
     This method is invoked when your app calls the readValueForCharacteristic: method,
     or when the peripheral notifies your app that the value of the characteristic for
     which notifications and indications are enabled has changed.
     
     If successful, the error parameter is nil.
     If unsuccessful, the error parameter returns the cause of the failure.
     */
    func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
        if error != nil {
            os_log("Error reported when updating state for characteristic", log: OSLog.default, type: .debug)
            return
        }

        if characteristic.uuid.uuidString == BLEUartRxCharacteristic {
            var stringValueWithDesc = String(data: characteristic.value!, encoding: String.Encoding.utf8)!
            os_log("Message Recieved: %{public}@", log: OSLog.default, type: .debug, stringValueWithDesc)
            if stringValueWithDesc.hasPrefix("v") {
                stringValueWithDesc.remove(at: stringValueWithDesc.startIndex)
                if stringValueWithDesc != "" && stringValueWithDesc.characters.count >= 3 {
                    voltageLabel.text = String(stringValueWithDesc) + " Volts"
                }
            } else if stringValueWithDesc.hasPrefix("t") {
                stringValueWithDesc.remove(at: stringValueWithDesc.startIndex)
                if stringValueWithDesc != "" && stringValueWithDesc.characters.count == 10 {
                    let date = Date(timeIntervalSince1970: Double(stringValueWithDesc)!)
                    let dateFormatter = DateFormatter()
                    dateFormatter.dateStyle = DateFormatter.Style.none
                    dateFormatter.timeStyle = DateFormatter.Style.short
                    timeLabel.text = dateFormatter.string(from: date)
                }
            } else if stringValueWithDesc.hasPrefix("r") {
                stringValueWithDesc.remove(at: stringValueWithDesc.startIndex)
                if stringValueWithDesc != "" && stringValueWithDesc.characters.count >= 7 {
                    nextRunLabel.text = stringValueWithDesc
                }
            } else if stringValueWithDesc.hasPrefix("d") {
                stringValueWithDesc.remove(at: stringValueWithDesc.startIndex)
                if stringValueWithDesc != "" && stringValueWithDesc.characters.count >= 1 {
                    durationLabel.text = stringValueWithDesc + " Seconds"
                }
            }
            
        }
    }
    
    
    // MARK: - Navigation
    
    // If returning to list of feeders, disconnect this one
    override func viewWillDisappear(_ animated : Bool) {
        super.viewWillDisappear(animated)
        
        if self.isMovingFromParentViewController {
            os_log("Moving to parent.  Disconnecting Device", log: OSLog.default, type: .debug)
            centralManager.cancelPeripheralConnection(feeder!)
            feederConnected = false
            haveSetDeviceLocation = false
            forceDisconnect = true
            voltageLabel.text = "Unknown"
            timeLabel.text = "Unknown"
            nextRunLabel.text = "Unknown"
            durationLabel.text = "Unknown"
        }
    }
    
    
    // MARK: - Private Methods
    

    // Use location manager to get lat and long
    func determineLocation() {

        let currentLocation = locationManager.location
        latitude = (currentLocation?.coordinate.latitude)!
        longitude = (currentLocation?.coordinate.longitude)!
        os_log("Determined Latitude: %{public}@ Determined Longitude %{public}@", log: OSLog.default, type: .debug, String(latitude), String(longitude))
    }
    
    // Sends time from phone to Smart Feeder Hardware
    func setTimeOnDevice() {
        
        disableAllButtons()
        activityIndicator.startAnimating()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            
            let seconds: TimeInterval = NSDate().timeIntervalSince1970
            self.sendToDevice(command: "ts", buffer: String(seconds))
            self.setLatAndLongOnDevice()
            self.getAndSetTimeAndVoltage()
            
            self.timer = Timer.scheduledTimer(timeInterval: 5, target: self, selector: #selector(self.getAndSetTimeAndVoltage), userInfo: nil, repeats: true)
            
            self.activityIndicator.stopAnimating()
            self.enableAllButtons()
        }
        
        

    }
    
    // Sends lat and long from phone to Smart Feeder Hardware
    func setLatAndLongOnDevice() {
        if( CLLocationManager.authorizationStatus() == CLAuthorizationStatus.authorizedWhenInUse || CLLocationManager.authorizationStatus() == CLAuthorizationStatus.authorized){
            determineLocation()
            if latitude != 0.0 && longitude != 0.0{
                sendToDevice(command: "la", buffer: String(latitude))
                sendToDevice(command: "lo", buffer: String(longitude))
                
                // also needs utc offset with lat/longitude.  Need in hours.
                let minsFromGMT = TimeZone.current.secondsFromGMT() / 60 / 60
                sendToDevice(command:"ut", buffer: String(minsFromGMT))
            }
            haveSetDeviceLocation = true
        }
    }
    
    // Sends command that will result in time and voltage being sent back
    func getAndSetTimeAndVoltage() {
        if feederConnected {
            sendToDevice(command: "st", buffer: "")
        }
    }
    
    // Utility method to send to device.  Wait is introduced to get unique buffer per command.  Could not find a way to flush.
    func sendToDevice(command: String, buffer: String) {
        
        let fullCommand =  command + buffer
        let dataToSend = fullCommand.data(using: String.Encoding.utf8)
        if (feeder != nil) {
            feeder?.writeValue(dataToSend!, for: transmitCharacteristic!, type: CBCharacteristicWriteType.withResponse)
            usleep(useconds_t(500 * ms))
        } else {
            os_log("Failed to send data to feeder.  Feeder not connected.", log: OSLog.default, type: .debug)
        }
    }
    
    // Loads run events from stored data
    private func loadFeederRunEvents() -> [FeederRunEvent]? {
        return NSKeyedUnarchiver.unarchiveObject(withFile: FeederRunEvent.ArchiveURL.path) as? [FeederRunEvent]
    }
    
    private func disableAllButtons() {
        UIApplication.shared.beginIgnoringInteractionEvents()
        navigationController?.navigationBar.isUserInteractionEnabled = false
        editButton.isEnabled = false
        synchButton.isEnabled = false
        feedNowButon.isEnabled = false
        
    }
    
    private func enableAllButtons() {
        editButton.isEnabled = true
        synchButton.isEnabled = true
        feedNowButon.isEnabled = true
        navigationController?.navigationBar.isUserInteractionEnabled = true
        UIApplication.shared.endIgnoringInteractionEvents()
    }
    
    
}

