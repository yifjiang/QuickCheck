//
//  ViewController.swift
//  QuickCheck
//
//  Created by James on 2016/12/3.
//  Copyright © 2016年 JiangYifan. All rights reserved.
//

import UIKit
import CoreData

//var isPresent:


class ViewController: UIViewController, UITableViewDelegate, UITableViewDataSource, UITextFieldDelegate {
    let rateLabelText = "Tip+Tax: "
    var guestNumber = 0;
    
    func getContext() -> NSManagedObjectContext {
        let appDelegate = UIApplication.shared.delegate as! AppDelegate
        return appDelegate.persistentContainer.viewContext
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        let fetchRequest = NSFetchRequest<NSFetchRequestResult>(entityName: "Person")
        do {
            let results = try getContext().fetch(fetchRequest)
            people = results as! [NSManagedObject]
        } catch {
            print("Error with request: \(error)")
        }
        Names.removeAll();
        for person in people {
            if let name = person.value(forKey: "name") as? String {
                Names.append(name)
            }
        }
        RoommateNames = Names
        IsPresent = Array(repeating: true, count: Names.count)
        HasOrdered = Array(repeating: nil, count: Names.count)
        shouldPay = Array(repeating: 0, count: Names.count)
        myTableView.addGestureRecognizer(UILongPressGestureRecognizer(target: self, action: #selector(ViewController.handleLongPress)))
        tipRateLabel.text = rateLabelText + (String(format: "%d", Int(tipRate*100))) + "%"
        toolbarDone.sizeToFit();
        toolbarDone.barStyle = .black
        let barButtonDone = UIBarButtonItem(barButtonSystemItem: .done, target: self, action: #selector(self.resignAll))
        toolbarDone.items = [barButtonDone]
        noTipField.inputAccessoryView = toolbarDone;
        withTipField.inputAccessoryView = toolbarDone;
        togetherSumField.inputAccessoryView = toolbarDone;
        noTipField.tag = TextFieldTag.noTipField.rawValue
        withTipField.tag = TextFieldTag.withTipField.rawValue
        togetherSumField.tag = TextFieldTag.togetherSum.rawValue
        myTableView.register(myCell.self, forCellReuseIdentifier: "Cell")
        // Do any additional setup after loading the view, typically from a nib.
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    
    
    @IBOutlet weak var myTableView: UITableView!
    var people = [NSManagedObject]()
    var RoommateNames=[String]()
    var Names:[String] = ["放爷", "申腿", "一凡", "泽宇"];
    var IsPresent:[Bool] = [true,true,true,true]
    var HasOrdered:[Double?] = [nil,nil,nil,nil]
    var shouldPay:[Double] = [0,0,0,0]
    var population: Int {
        var returnValue = 0
        for present in IsPresent {
            if present {
                returnValue += 1
            }
        }
        return returnValue
    }
    @IBOutlet weak var togetherSumField: UITextField!
    @IBOutlet weak var noTipField: UITextField!
    @IBOutlet weak var withTipField: UITextField!
    var memoWithTip:String?
    var previousRate : Double = 0.15
    let toolbarDone = UIToolbar();
    var together: Double {
        get {
            if let returnValue = Double(togetherSumField.text!) {
                return returnValue
            }else{
                return 0
            }
        }
        set {
            if newValue != 0 {
                togetherSumField.text = String(format: "%.2f", newValue)
            }
            doneHasOrdered()
        }
    }
    
    var sumWithoutTip: Double {
        get {
            if let returnValue = Double(noTipField.text!){
                return returnValue
            }else{
                return 0
            }
        }
        set {
            print(newValue)
            noTipField.text = String(format: "%.2f", newValue)
            let newValueOfSumWithTip = newValue*(1.0+tipRate)
            if let sumCalculated = calculateSum(){
                if newValue - sumCalculated > together {
                    together = newValue - sumCalculated
                }
            }
            if sumWithTip != newValueOfSumWithTip {
                sumWithTip = newValueOfSumWithTip
            }
        }
    }
    
    var sumWithTip: Double {
        get {
            if let returnValue = Double(withTipField.text!){
                return returnValue
            }else{
                return 0
            }
        }
        set {
            withTipField.text = String(format: "%.2f", newValue)
            if sumWithoutTip != 0 {
                let temporaryTipRate = Float(newValue/sumWithoutTip - 1.0)
                mySlider.value = temporaryTipRate
                tipRateLabel.text = rateLabelText + (NSString(format: "%d", Int(temporaryTipRate*100)) as String) + "%"
                updateResult()
            }
        }
    }
    
    var tipRate: Double {
        get {
            return Double(round(mySlider.value*100.0))/100.0
        }
        set {
            mySlider.value = Float(newValue)
            tipRateLabel.text = rateLabelText + (NSString(format: "%d", Int(newValue*100)) as String) + "%"
            let newValueOfSumWithTip = (sumWithoutTip * (1.0 + newValue))
            if newValueOfSumWithTip != sumWithTip {
                sumWithTip = newValueOfSumWithTip
            }
        }
    }
    
    enum PersonType {
        case guest, existing;
    }
    
    enum TextFieldTag : Int {
        case togetherSum = -3, noTipField = -2, withTipField = -1
    }
    
    override var prefersStatusBarHidden: Bool{
        return false
    }
    
    func numberOfSections(in tableView: UITableView) -> Int {
        return 1;
    }
    
    var numberOfPeople: Int {
        return Names.count;
    }
    
    func getIndexPath(from row: Int) -> IndexPath {
        return IndexPath(row: row, section: 0)
    }
    
    func onNameButton(sender:UIButton) {
        let buttonRow = sender.tag
//        print(buttonRow)
        IsPresent[buttonRow] = !IsPresent[buttonRow]
        sender.isSelected = !sender.isSelected
        doneHasOrdered()
    }
    
    func resignAll() {
        noTipField.resignFirstResponder()
        withTipField.resignFirstResponder()
        togetherSumField.resignFirstResponder()
        for i in 0..<numberOfPeople {
            if let cell = myTableView.cellForRow(at: getIndexPath(from: i)) as? myCell{
                cell.Amount.resignFirstResponder();
            }
        }
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        if let cell = tableView.dequeueReusableCell(withIdentifier: "aCell", for: indexPath) as? myCell{
            cell.NameButton.setTitle(Names[indexPath.row], for: .normal);
            cell.NameButton.setTitle(Names[indexPath.row], for: .selected);
            cell.NameButton.isSelected = IsPresent[indexPath.row];
            cell.NameButton.tag = indexPath.row
            cell.NameButton.addTarget(self, action: #selector(self.onNameButton), for: .touchUpInside)
            cell.Amount.delegate = self;
            cell.Amount.inputAccessoryView = toolbarDone;
            cell.Amount.tag = indexPath.row
            if let amount = HasOrdered[indexPath.row] {
                cell.Amount.text = NSString(format: "%.2f", amount) as String
            }else{
                cell.Amount.text = ""
            }
            if shouldPay[indexPath.row] != 0 {
                cell.Result.text = NSString(format: "%.2f", shouldPay[indexPath.row]) as String
            }else{
                cell.Result.text = "N/A"
            }
            return cell;
        }else{
            return tableView.dequeueReusableCell(withIdentifier: "aCell", for: indexPath);
        }
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return numberOfPeople;
    }
    
    func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCellEditingStyle, forRowAt indexPath: IndexPath) {
        if editingStyle == .delete {
            deleteAPerson(by: indexPath.row)
        }
    }
    
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        textField.resignFirstResponder();
        return true;
    }
    
    func changeName(of index: Int, for person: PersonType){
        let promptSheet = UIAlertController(title: "Change the name", message: "New name for ", preferredStyle: .alert)
        switch person {
        case .existing:
            promptSheet.message?.append(Names[index]+": ")
        case .guest:
            promptSheet.message = "Name for "+Names[index]+": "
        }
        promptSheet.addAction(UIAlertAction(title: "Done", style: .default, handler: { (_) in
            if let newName = promptSheet.textFields?.first?.text{
                if newName != ""{
                    self.Names[index] = newName
                    self.myTableView.beginUpdates();
                    self.myTableView.reloadRows(at: [IndexPath(row: index, section:0)], with: .none)
                    self.myTableView.endUpdates();
                }
            }
        }))
        if person == .existing {
            promptSheet.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: {_ in}))
        }
        promptSheet.addTextField { (textField) in
            textField.placeholder = self.Names[index]
        }
        promptSheet.textFields?.first?.becomeFirstResponder()
        self.present(promptSheet, animated: true, completion: nil)
    }
    
    func changeNameOfNewGuest() {
        changeName(of: numberOfPeople-1, for: .guest)
    }
    
    func changeNameOfExisting(by index:Int) {
        changeName(of: index, for: .existing)
    }
    
    func makeGuest(by name:String) {
        let managedContext = getContext()
        var index = RoommateNames.index(of: name)
        while index != nil {
            RoommateNames.remove(at: index!)
            managedContext.delete(people[index!])
            people.remove(at: index!)
            index = RoommateNames.index(of: name)
        }
        do {
            try managedContext.save()
        } catch {
            print("Could not save \(error)")
        }
    }
    
    func makeRoommate(by name:String) {
        RoommateNames.append(name)
        let managedContext = getContext()
        let entity = NSEntityDescription.entity(forEntityName: "Person", in: managedContext)
        let person = NSManagedObject(entity: entity!, insertInto: managedContext)
        person.setValue(name, forKey: "name")
        do {
            try managedContext.save()
        } catch {
            print("Could not save \(error)")
        }
        people.append(person)
    }
    
    func actionsOfExisting(by index:Int){
        let alert  = UIAlertController(title: "Select an action", message: "with "+Names[index]+":", preferredStyle: .actionSheet)
        alert.modalPresentationStyle = .popover
        if let ppc = alert.popoverPresentationController{
            if let cell = myTableView.cellForRow(at: IndexPath(row: index, section: 0)) as? myCell{
                ppc.sourceView = cell.NameButton
            }
        }
        alert.addAction(UIAlertAction(title: "Cancel", style: UIAlertActionStyle.cancel, handler: {(action: UIAlertAction)-> Void in }))
        alert.addAction(UIAlertAction(title: "Change Name", style: .default, handler: {_ in self.changeNameOfExisting(by: index)}))
//        alert.addAction(UIAlertAction(title: "Delete", style: .destructive, handler: {_ in self.deleteAPerson(by: index)}))
        if let cell = myTableView.cellForRow(at: getIndexPath(from: index)) as? myCell{
            if let name = cell.NameButton.title(for: .normal) {
                if RoommateNames.contains(name){
                    alert.addAction(UIAlertAction(title: "Becomes Guest", style: .destructive, handler: {_ in self.makeGuest(by: name)}))
                }else{
                    alert.addAction(UIAlertAction(title: "Becomes Roommate", style: .destructive, handler: {_ in self.makeRoommate(by: name)}))
                }
            }
        }
        self.present(alert, animated: true, completion: {})
    }
    
    func handleLongPress(from gestureRecogizer: UILongPressGestureRecognizer){
        if gestureRecogizer.state == .began {
            let indexPath = myTableView.indexPathForRow(at: gestureRecogizer.location(in: myTableView))
            if let row = indexPath?.row {
                actionsOfExisting(by: row)
            }
        }
    }
    
    func addNewPerson() {
        guestNumber += 1
        Names.append("Guest " + String(guestNumber))
        IsPresent.append(true)
        HasOrdered.append(nil)
        shouldPay.append(0)
        CATransaction.begin()
        myTableView.beginUpdates();
        CATransaction.setCompletionBlock {
            self.myTableView.reloadData()
            self.doneHasOrdered()
        }
        self.changeNameOfNewGuest();
        myTableView.insertRows(at: [IndexPath(row: numberOfPeople-1, section: 0)], with: .automatic )
        myTableView.endUpdates();
        CATransaction.commit()
        return
    }
    
    func deleteAPerson(by index: Int) {
        makeGuest(by: Names[index])
        Names.remove(at: index)
        IsPresent.remove(at: index)
        HasOrdered.remove(at: index)
        shouldPay.remove(at: index)
        CATransaction.begin()
        myTableView.beginUpdates();
        CATransaction.setCompletionBlock {
            self.myTableView.reloadData()
            self.doneHasOrdered()
        }
        myTableView.deleteRows(at: [getIndexPath(from: index)], with: .automatic)
        myTableView.endUpdates();
        CATransaction.commit();
    }
    
    @IBAction func onAddNewPersonButton(_ sender: UIButton) {
        addNewPerson();
    }
    
    func updateSlider(sumWithoutTip:Double, sumWithTip:Double){
        mySlider.value = Float(sumWithTip/sumWithoutTip-1.0)
    }
    @IBOutlet weak var mySlider: UISlider!
    @IBOutlet weak var tipRateLabel: UILabel!
    
    @IBAction func onSliderChange(_ sender: UISlider) {
        if previousRate != tipRate{
            previousRate = tipRate
            tipRate = previousRate
            updateResult();
        }
    }
    
    func calculateSum() -> Double? {
        var sum : Double = 0;
        for i in 0..<numberOfPeople {
            if IsPresent[i]  {
                if let amount = HasOrdered[i] {
                    sum += amount
                }else{
                    return nil
                }
            }
        }
        return sum
    }
    
    func doneHasOrdered(){
        var sum : Double = together;
        var sumFromHasOrderdisReady: Bool = true
        for i in 0..<numberOfPeople {
            if IsPresent[i]  {
                if let amount = HasOrdered[i] {
                    sum += amount
                }else{
                    sumFromHasOrderdisReady = false
                }
            }
        }
        if sumFromHasOrderdisReady {
            if sumWithoutTip != sum {
                sumWithoutTip = sum;
            }
        }
        updateResult()
    }
    
    func updateResult() {
        if sumWithoutTip != 0 && sumWithTip != 0 {
            for i in 0..<numberOfPeople {
                if IsPresent[i] {
                    if let amount = HasOrdered[i] {
                        shouldPay[i] = (together/Double(population) + amount)/sumWithoutTip*sumWithTip
                    }else{
                        shouldPay[i] = (together/Double(population))/sumWithoutTip*sumWithTip
                    }
                }else{
                    shouldPay[i] = 0
                }
            }
            for i in 0..<numberOfPeople {
                if let cell = myTableView.cellForRow(at: getIndexPath(from: i)) as? myCell{cell.NameButton.setTitle(Names[i], for: .normal);
                    cell.NameButton.setTitle(Names[i], for: .selected);
                    cell.NameButton.isSelected = IsPresent[i];
                    cell.NameButton.tag = i
                    cell.NameButton.addTarget(self, action: #selector(self.onNameButton), for: .touchUpInside)
                    if shouldPay[i] != 0 {
                        cell.Result.text = NSString(format: "%.2f", shouldPay[i]) as String
                    }else{
                        cell.Result.text = "N/A"
                    }
                }
            }
//            myTableView.reloadData()
        }
    }
    
    func textFieldDidEndEditing(_ textField: UITextField) {
        if let text = textField.text {
            if let amount = Double(text) {
                switch textField.tag {
                case TextFieldTag.noTipField.rawValue:
                    sumWithoutTip = amount
                    doneHasOrdered()
                case TextFieldTag.togetherSum.rawValue:
                    together = amount
                case TextFieldTag.withTipField.rawValue:
                    sumWithTip = amount
                default:
                    HasOrdered[textField.tag] = amount
                    doneHasOrdered()
                }
            }else{
                let amount = 0.0
                switch textField.tag {
                case TextFieldTag.noTipField.rawValue:
                    sumWithoutTip = amount
                    doneHasOrdered()
                case TextFieldTag.togetherSum.rawValue:
                    together = amount
                case TextFieldTag.withTipField.rawValue:
                    sumWithTip = amount
                default:
                    HasOrdered[textField.tag] = nil
                    doneHasOrdered()
                }
            }
        }
    }
    
    //TODO:-extract model from the view
    
//    func updateTipRate() {
//        tipRateLabel.text = "Tip Rate : " + (NSString(format: "%d", Int(mySlider.value*100)) as String) + "%"
//    }
//    
//    func updateResult(sumInputed: Double, sumWithTip: Double) {
//        var population : Double = 0;
//        for i in 0..<numberOfPeople {
//            if let cell = myTableView.cellForRow(at: IndexPath(row: i, section: 0)) as? myCell{
//                if (cell.NameButton.isSelected) {
//                    population += 1;
//                }
//            }
//        }
//        var together : Double = 0;
//        if togetherSumField.text != nil {
//            if let amount = Double(togetherSumField.text!){
//                together = amount;
//            }
//        }
//        for i in 0..<numberOfPeople {
//            if let cell = myTableView.cellForRow(at: IndexPath(row: i, section: 0)) as? myCell{
//                if cell.NameButton.isSelected {
//                    if let amount = Double(cell.Amount.text!) {
//                        cell.Result.text = NSString(format: "%.2f", (amount+together/population)/sumInputed*sumWithTip) as String;
//                        shouldPay[i] = (amount+together/population)/sumInputed*sumWithTip
//                    }else{
//                        if together != 0 {
//                            cell.Result.text = NSString(format: "%.2f", (together/population)/sumInputed*sumWithTip) as String;
//                            shouldPay[i] = (together/population)/sumInputed*sumWithTip
//                        }else{
//                            cell.Result.text = "N/A"
//                            shouldPay[i] = 0
//                        }
//                    }
//                }else{
//                    cell.Result.text = "N/A"
//                    shouldPay[i] = 0
//                }
//            }
//        }
//    }
//    
//    func updateTip() {
//        var sumInputed : Double?;
//        if (noTipField.text != nil) {
//            sumInputed = Double(noTipField.text!);
//        }
//        if sumInputed != nil {
//            let sumWithTip : Double? = sumInputed!*(1.0 + tipRate);
//            withTipField.text = NSString(format: "%.2f", sumWithTip!) as String;
//            if sumWithTip == nil {
//                return;
//            }
//            updateResult(sumInputed: sumInputed!, sumWithTip: sumWithTip!)
//        }
//    }
//    
//    func calculate() {
//        <#function body#>
//    }
//    
//    func calculateWithUIUpdate() {
//        var together : Double = 0;
//        if togetherSumField.text != nil {
//            if let amount = Double(togetherSumField.text!){
//                together = amount;
//            }
//        }
//        
//        var sumInputed : Double?;
//        if (noTipField.text != nil) {
//            sumInputed = Double(noTipField.text!);
//        }
//        
//        var sum:Double = 0;
//        var population : Double = 0;
//        for i in 0..<numberOfPeople {
//            if let cell = myTableView.cellForRow(at: IndexPath(row: i, section: 0)) as? myCell{
//                IsPresent[i] = cell.NameButton.isSelected;
//                if (cell.NameButton.isSelected) {
//                    population += 1;
//                    if cell.Amount.text != nil {
//                        if let amount = Double(cell.Amount.text!) {
//                            HasOrdered[i] = amount;
//                            sum = sum + amount;
//                        } else if (sumInputed == nil) {
//                            return
//                        }
//                    }
//                }
//            }
//        }
////        print(sumInputed)
//        sum = sum + together;
//        var realSum : Double;
//        if sumInputed != nil {
//            realSum = sumInputed!;
//        }else{
//            realSum = sum;
//            noTipField.text = NSString(format: "%.2f", realSum) as String;
//        }
//        var sumWithTip = Double(withTipField.text!)
//        if withTipField.text == "" || withTipField.text == nil {
//            sumWithTip = realSum*(1.0 + tipRate);
//            withTipField.text = NSString(format: "%.2f", sumWithTip!) as String;
//        }else{
//            sumWithTip = Double(withTipField.text!);
////            print(withTipField.text!);
//        }
//        
//        if sumWithTip == nil {
//            return;
//        }
//        for i in 0..<numberOfPeople {
//            if let cell = myTableView.cellForRow(at: IndexPath(row: i, section: 0)) as? myCell{
//                if cell.NameButton.isSelected {
//                    if let amount = Double(cell.Amount.text!) {
//                        shouldPay[i] = (amount+together/population)/realSum*sumWithTip!;
//                        cell.Result.text = NSString(format: "%.2f", (amount+together/population)/realSum*sumWithTip!) as String;
//                    }else{
//                        if together != 0 {
//                            cell.Result.text = NSString(format: "%.2f", (together/population)/realSum*sumWithTip!) as String;
//                            shouldPay[i] = (together/population)/realSum*sumWithTip!
//                        }else{
//                            cell.Result.text = "N/A"
//                            shouldPay[i] = 0
//                        }
//                    }
//                }else{
//                    cell.Result.text = "N/A"
//                    shouldPay[i] = 0
//                }
//            }
//        }
//    }

}


class myCell: UITableViewCell {
    @IBOutlet weak var NameButton: UIButton!
    @IBOutlet weak var Amount: UITextField!
    @IBOutlet weak var Result: UILabel!
//    @IBAction func togglePresent(_ sender: UIButton) {
//        NameButton.isSelected = !NameButton.isSelected;
//    }
    
    //    init(name:String, amount:Double = 0, result:Double = 0) {
    //        super.init(style: <#T##UITableViewCellStyle#>, reuseIdentifier: <#T##String?#>)
    //        NameButton.setTitle(name, for: .normal)
    //        NameButton.setTitle(name, for: .selected)
    //    }
    //
    //    required init?(coder aDecoder: NSCoder) {
    //        fatalError("init(coder:) has not been implemented")
    //    }
    
}
