//
//  SearchBar.swift
//  DanceDeets
//
//  Created by LambertMike on 2015/09/26.
//  Copyright © 2015年 david.xiang. All rights reserved.
//

import CoreLocation
import Foundation

class SearchBar : NSObject, UITextFieldDelegate, UITableViewDelegate, UITableViewDataSource {

    typealias SearchHandler = (String, String) -> Void

    var controller: EventStreamViewController
    var searchHandler: SearchHandler
    var blurOverlay: UIView?
    var autosuggestedLocations:[String] = []
    var currentGeooder:CurrentGeocode?

    init(controller: EventStreamViewController, searchHandler: SearchHandler) {
        self.controller = controller
        self.searchHandler = searchHandler
        super.init()

        // auto suggest terms when search text field is tapped
        controller.autosuggestTable.alpha = 0
        controller.autosuggestTable.backgroundColor = UIColor.clearColor()
        controller.autosuggestTable.delegate = self
        controller.autosuggestTable.dataSource = self
        controller.autosuggestTable.tintColor = ColorFactory.white50()

        controller.searchTextCancelButton.alpha = 0
        controller.searchTextCancelButton.addTarget(self, action: "cancelButtonPressed", forControlEvents: .TouchUpInside)
        controller.locationSearchField.addTarget(self, action: "locationFieldUpdated", forControlEvents: UIControlEvents.EditingChanged)

        // search text field styling
        configureField(controller.locationSearchField, defaultText: "Location", iconName: "pinIcon")
        configureField(controller.keywordSearchField, defaultText: "Keywords", iconName: "searchIconSmall")

        // blur overlay is used for background of auto suggest table
        blurOverlay = controller.view.addDarkBlurOverlay()
        controller.view.insertSubview(blurOverlay!, belowSubview: controller.customNavigationView)
        blurOverlay?.alpha = 0
    }

    func configureField(field: UITextField, defaultText: String, iconName: String) {
        let placeholder = NSMutableAttributedString(string: defaultText)
        placeholder.setColor(ColorFactory.white50())
        placeholder.setFont(UIFont(name: "Interstate-Light", size: 12.0)!)
        field.attributedPlaceholder = placeholder

        let imageView:UIImageView = UIImageView(image: UIImage(named: iconName)!)
        imageView.tintColor = ColorFactory.white50()
        imageView.contentMode = UIViewContentMode.Right
        imageView.frame = CGRectMake(0, 0, imageView.image!.size.width + 10, imageView.image!.size.height)
        field.delegate = self
        field.clearButtonMode = UITextFieldViewMode.WhileEditing
        field.leftView = imageView
        field.leftViewMode = UITextFieldViewMode.Always
        field.textAlignment = .Left
    }

    func textFieldDidEndEditing(textField: UITextField) {
        self.autosuggestedLocations = []
        self.controller.autosuggestTable.reloadData()
    }

    func beginEditing() {

    }

    func endEditing() {
        UIView.animateWithDuration(0.5, delay: 0.0, options: .CurveEaseInOut, animations: { () -> Void in
            self.blurOverlay?.alpha = 0.0
            self.controller.autosuggestTable?.alpha = 0.0
            self.controller.searchTextCancelButton.alpha = 0.0
            self.controller.settingsButton.alpha = 1.0
            self.controller.textFieldsEqualWidthConstraint.priority = 900
            self.controller.locationMaxWidthConstraint.priority = 500
            self.controller.keywordMaxWidthConstraint.priority = 500

            self.controller.navigationTitle.alpha = 1

            self.controller.view.layoutIfNeeded()
            }) {(Bool)->Void in
                controller.view.endEditing(true)
        }
    }

    func textFieldShouldReturn(textField: UITextField) -> Bool {
        endEditing()
        searchHandler(controller.locationSearchField.text!, controller.keywordSearchField.text!)
        return true
    }

    func cancelButtonPressed() {
        endEditing()
    }


    func textFieldDidBeginEditing(textField: UITextField) {
        UIView.animateWithDuration(0.5, delay: 0.0, options: .CurveEaseInOut, animations: { () -> Void in
            self.blurOverlay?.alpha = 1.0
            self.controller.autosuggestTable?.alpha = 1.0
            self.controller.textFieldsEqualWidthConstraint.priority = 500
            self.controller.settingsButton.alpha = 0.0
            if (textField == self.controller.locationSearchField) {
                self.controller.locationMaxWidthConstraint.priority = 900
                self.controller.keywordMaxWidthConstraint.priority = 500
            } else {
                self.controller.keywordMaxWidthConstraint.priority = 900
                self.controller.locationMaxWidthConstraint.priority = 500
            }
            self.controller.view.layoutIfNeeded()
            }) {(Bool)->Void in
        }
        //animateWithDuration(duration: NSTimeInterval, delay: NSTimeInterval, options: UIViewAnimationOptions, animations: () -> Void, completion: ((Bool) -> Void)?)
        UIView.animateWithDuration(0.25, delay: 0.0, options: .CurveEaseInOut, animations: { () -> Void in
                self.controller.navigationTitle.alpha = 0
            }) {(Bool)->Void in
                UIView.animateWithDuration(0.25, delay: 0.0, options: .CurveEaseInOut, animations: { () -> Void in
                    self.controller.searchTextCancelButton.alpha = 1.0
                    }) {(Bool)->Void in }
        }
    }

    func locationFieldUpdated() {
        let currentText = controller.locationSearchField.text
        if (currentText?.characters.count > 0) {
            UIApplication.sharedApplication().networkActivityIndicatorVisible = true
            GooglePlaceAPI.autoSuggestCity(currentText!, completion: { (autosuggests: [String]!, error: NSError!) -> Void in
                UIApplication.sharedApplication().networkActivityIndicatorVisible = false
                if (error == nil) {
                    dispatch_async(dispatch_get_main_queue(), {
                        self.autosuggestedLocations = autosuggests
                        self.controller.autosuggestTable.reloadData()
                    })
                }
            })
        } else {
            autosuggestedLocations = []
            controller.autosuggestTable.reloadData()
        }
    }

    func numberOfSectionsInTableView(tableView: UITableView) -> Int {
        return 2
    }

    // MARK: UITableViewDataSource
    func tableView(tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        if section == 0 {
            return 1
        } else {
            return autosuggestedLocations.count
        }
    }

    func tableView(tableView: UITableView, cellForRowAtIndexPath indexPath: NSIndexPath) -> UITableViewCell {
        if indexPath.section == 0 {
            let cell = tableView.dequeueReusableCellWithIdentifier("autosuggestCityCell", forIndexPath: indexPath) as! SettingsCell
            cell.label.text = "Current Location"
            return cell
        } else {
            let cell = tableView.dequeueReusableCellWithIdentifier("autosuggestCityCell", forIndexPath: indexPath) as! SettingsCell
            cell.label.text = autosuggestedLocations[indexPath.row]
            return cell
        }
    }

    func tableView(tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        return nil
    }

    func tableView(tableView: UITableView, heightForFooterInSection section: Int) -> CGFloat {
        return CGFloat.min
    }

    func tableView(tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        return CGFloat.min
    }

    func tableView(tableView: UITableView, heightForRowAtIndexPath indexPath: NSIndexPath) -> CGFloat {
        return 44
    }

    // MARK: UITableViewDelegate
    func tableView(tableView: UITableView, didSelectRowAtIndexPath indexPath: NSIndexPath) {
        if indexPath.section == 0 {
            controller.locationSearchField.text = "Finding location..." //TODO: look up location!!!
            currentGeooder = CurrentGeocode(completionHandler: geocodeCompletionHandler)
        } else {
            controller.locationSearchField.text = autosuggestedLocations[indexPath.row]
            textFieldShouldReturn(controller.locationSearchField)
        }
    }

    func geocodeCompletionHandler(optionalPlacemark: CLPlacemark?) {
        if let placemark = optionalPlacemark {
            let fullText = "\(placemark.locality!), \(placemark.administrativeArea!), \(placemark.country!)"
            self.controller.locationSearchField.text = fullText
            textFieldShouldReturn(controller.locationSearchField)
        } else {
            self.controller.locationSearchField.text = ""
            controller.locationFailureAlert.show()
        }
    }
    /*
    // MARK: UITableViewDataSource / UITableViewDelegate

    func tableView(tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return SEARCH_AUTOSUGGEST_TERMS.count
    }


    func tableView(tableView: UITableView, didSelectRowAtIndexPath indexPath: NSIndexPath) {
        if(tableView == searchAutoSuggestTableView){
            let term = SEARCH_AUTOSUGGEST_TERMS[indexPath.row] as String
            searchKeyword = term
            hideAutoSuggestTable()

            refreshEvents()
        }
    }
    */

}