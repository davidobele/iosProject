//
//  ProfileViewController.swift
//  Planter
//
//  Created by David Obele on 4/15/25.
//

import UIKit

class ProfileViewController: UIViewController, UIPickerViewDelegate, UIPickerViewDataSource {
    
    // MARK: - Outlets
    @IBOutlet weak var usernameTextField: UITextField!
    @IBOutlet weak var darkModeSwitch: UISwitch!
    
    // UI Container References
    @IBOutlet weak var profileSectionView: UIView!
    @IBOutlet weak var appearanceSectionView: UIView!
    @IBOutlet weak var favoritesSectionView: UIView!
    
    // Timezone picker
    private var timezonePicker: UIPickerView!
    private var timezoneLabel: UILabel!
    
    // Section Headers
    @IBOutlet weak var profileHeaderLabel: UILabel!
    @IBOutlet weak var appearanceHeaderLabel: UILabel!
    @IBOutlet weak var favoritesHeaderLabel: UILabel!
    
    // Text labels
    @IBOutlet weak var usernameLabel: UILabel!
    @IBOutlet weak var darkModeLabel: UILabel!
    @IBOutlet weak var noFavoritesLabel: UILabel!
    
    // MARK: - Properties
    private let userDefaults = UserDefaults.standard
    private let darkModeKey = "isDarkModeEnabled"
    private let usernameKey = "username"
    private let timezoneKey = "selectedTimezone"
    
    // Common timezones for sports viewing
    private let commonTimezones = [
        ("Local", TimeZone.current.identifier),
        ("Eastern (EST/EDT)", "America/New_York"),
        ("Central (CST/CDT)", "America/Chicago"),
        ("Mountain (MST/MDT)", "America/Denver"),
        ("Pacific (PST/PDT)", "America/Los_Angeles"),
        ("London (GMT/BST)", "Europe/London"),
        ("Central Europe", "Europe/Paris"),
        ("Tokyo (JST)", "Asia/Tokyo")
    ]
    
    // Current selected timezone
    private var selectedTimezoneIndex: Int = 0
    
    // Notification names
    private let usernameChangedNotification = NSNotification.Name("UsernameChangedNotification")
    private let timezoneChangedNotification = NSNotification.Name("TimezoneChangedNotification")
    
    // Favorites manager
    private let favoritesManager = FavoritesManager.shared
    
    // TableView for displaying favorites
    private var favoritesTableView: UITableView?
    
    // MARK: - Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        loadSavedSettings()
        
        // Add notifications for keyboard handling
        NotificationCenter.default.addObserver(self, selector: #selector(keyboardWillShow), name: UIResponder.keyboardWillShowNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(keyboardWillHide), name: UIResponder.keyboardWillHideNotification, object: nil)
        
        // Add tap gesture to dismiss keyboard when tapping outside
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(dismissKeyboard))
        view.addGestureRecognizer(tapGesture)
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        saveSettings()
        saveAllSettings()
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        // Refresh favorites when view appears
        setupFavoritesSection()
    }
    
    // MARK: - Setup
    private func setupUI() {
        // Round the corners of containers
        [profileSectionView, appearanceSectionView, favoritesSectionView].forEach { view in
            view?.layer.cornerRadius = 12
            view?.clipsToBounds = true
        }
        
        // Setup dark mode switch action
        darkModeSwitch.addTarget(self, action: #selector(darkModeSwitchChanged), for: .valueChanged)
        
        // Setup text field's delegate
        usernameTextField.delegate = self
        
        // Setup timezone picker in appearance section
        setupTimezonePicker()
        // Setup favorites section
        setupFavoritesSection()
        
        // Listen for favorites changes
        NotificationCenter.default.addObserver(self, 
                                               selector: #selector(favoritesChanged), 
                                               name: FavoritesManager.favoritesChangedNotification, 
                                               object: nil)
    }
    
    private func setupFavoritesSection() {
        // Check if we have favorites
        let favorites = favoritesManager.getAllFavorites()
        
        if favorites.isEmpty {
            // Show "No favorites yet" label
            noFavoritesLabel.isHidden = false
            // Remove table view if it exists
            favoritesTableView?.removeFromSuperview()
            favoritesTableView = nil
            
            // Reset favorites section height to default
            for constraint in favoritesSectionView.constraints {
                if constraint.firstAttribute == .height {
                    constraint.isActive = false
                }
            }
            favoritesSectionView.heightAnchor.constraint(equalToConstant: 60).isActive = true
            
        } else {
            // Hide "No favorites yet" label
            noFavoritesLabel.isHidden = true
            
            // Set fixed height for favorites section to allow scrolling
            let fixedHeight: CGFloat = 200 // Fixed height for scrolling area
            
            // Remove any existing height constraints
            for constraint in favoritesSectionView.constraints {
                if constraint.firstAttribute == .height {
                    constraint.isActive = false
                }
            }
            
            // Add new fixed height constraint
            favoritesSectionView.heightAnchor.constraint(equalToConstant: fixedHeight).isActive = true
            
            // Set up or update table view
            if favoritesTableView == nil {
                // Create table view
                let tableView = UITableView(frame: .zero, style: .plain)
                tableView.translatesAutoresizingMaskIntoConstraints = false
                tableView.delegate = self
                tableView.dataSource = self
                tableView.register(UITableViewCell.self, forCellReuseIdentifier: "FavoriteCell")
                tableView.isScrollEnabled = true // Explicitly enable scrolling
                tableView.backgroundColor = .clear
                tableView.separatorStyle = .none
                tableView.rowHeight = 50
                tableView.showsVerticalScrollIndicator = true
                tableView.bounces = true
                
                // Make the table view clip to bounds and round corners like the container
                tableView.clipsToBounds = true
                tableView.layer.cornerRadius = 8
                
                // Add to favorites section
                favoritesSectionView.addSubview(tableView)
                
                // Setup constraints - ensure table view fills the favorites section
                NSLayoutConstraint.activate([
                    tableView.topAnchor.constraint(equalTo: favoritesSectionView.topAnchor, constant: 8),
                    tableView.leadingAnchor.constraint(equalTo: favoritesSectionView.leadingAnchor, constant: 8),
                    tableView.trailingAnchor.constraint(equalTo: favoritesSectionView.trailingAnchor, constant: -8),
                    tableView.bottomAnchor.constraint(equalTo: favoritesSectionView.bottomAnchor, constant: -8)
                ])
                
                favoritesTableView = tableView
            }
            
            // Reload table view data
            favoritesTableView?.reloadData()
        }
    }
    
    @objc private func favoritesChanged() {
        setupFavoritesSection()
    }
    
    private func loadSavedSettings() {
        // Load dark mode preference
        let isDarkMode = userDefaults.bool(forKey: darkModeKey)
        darkModeSwitch.isOn = isDarkMode
        applyTheme(isDarkMode: isDarkMode)
        
        // Load saved username
        if let username = userDefaults.string(forKey: usernameKey) {
            usernameTextField.text = username
        }
        
        // Load saved timezone preference
        if let savedTimezone = userDefaults.string(forKey: timezoneKey) {
            // Find index of saved timezone
            if let index = commonTimezones.firstIndex(where: { $0.1 == savedTimezone }) {
                selectedTimezoneIndex = index
                timezonePicker.selectRow(index, inComponent: 0, animated: false)
                updateTimezoneLabel()
            }
        } else {
            // Default to local timezone if not set
            selectedTimezoneIndex = 0
            userDefaults.set(commonTimezones[0].1, forKey: timezoneKey)
        }
    }
    
    // Save all settings
    private func saveAllSettings() {
        // Save username if it has changed
        let currentUsername = usernameTextField.text ?? ""
        let savedUsername = userDefaults.string(forKey: usernameKey) ?? ""
        
        if currentUsername != savedUsername {
            userDefaults.set(currentUsername, forKey: usernameKey)
            NotificationCenter.default.post(name: usernameChangedNotification, object: nil)
        }
        
        // Save timezone (handled in pickerView didSelectRow, but ensure it's saved)
        let timezoneIdentifier = commonTimezones[selectedTimezoneIndex].1
        userDefaults.set(timezoneIdentifier, forKey: timezoneKey)
    }
    
    private func saveSettings() {
        userDefaults.set(darkModeSwitch.isOn, forKey: darkModeKey)
        userDefaults.set(usernameTextField.text, forKey: usernameKey)
        userDefaults.set(commonTimezones[selectedTimezoneIndex].1, forKey: timezoneKey)
    }
    
    // MARK: - Actions
    @objc private func darkModeSwitchChanged() {
        userDefaults.set(darkModeSwitch.isOn, forKey: darkModeKey)
        applyTheme(isDarkMode: darkModeSwitch.isOn)
    }
    
    private func applyTheme(isDarkMode: Bool) {
        if isDarkMode {
            // Apply dark theme to the entire app
            // Use modern API to avoid deprecated warning
            if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene {
                windowScene.windows.forEach { window in
                    window.overrideUserInterfaceStyle = .dark
                }
            }
            
            // Apply dark theme to this view controller specifically
            view.backgroundColor = .systemGray6
            
            // Update section views
            [profileSectionView, appearanceSectionView, favoritesSectionView].forEach { sectionView in
                sectionView?.backgroundColor = .systemGray5
            }
            
            // Update text colors
            [usernameLabel, darkModeLabel, noFavoritesLabel].forEach { label in
                label?.textColor = .white
            }
            
            // Update section headers
            [profileHeaderLabel, appearanceHeaderLabel, favoritesHeaderLabel].forEach { headerLabel in
                headerLabel?.textColor = .lightGray
            }
            
            // Update text field
            usernameTextField.textColor = .white
            usernameTextField.attributedPlaceholder = NSAttributedString(
                string: usernameTextField.placeholder ?? "Enter username",
                attributes: [NSAttributedString.Key.foregroundColor: UIColor.lightGray]
            )
            
            // Update table view if it exists
            favoritesTableView?.reloadData()
        } else {
            // Apply light theme to the entire app
            // Use modern API to avoid deprecated warning
            if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene {
                windowScene.windows.forEach { window in
                    window.overrideUserInterfaceStyle = .light
                }
            }
            
            // Apply light theme to this view controller specifically
            view.backgroundColor = .systemGray6
            
            // Update section views
            [profileSectionView, appearanceSectionView, favoritesSectionView].forEach { sectionView in
                sectionView?.backgroundColor = .white
            }
            
            // Update text colors
            [usernameLabel, darkModeLabel, noFavoritesLabel].forEach { label in
                label?.textColor = .black
            }
            
            // Update section headers
            [profileHeaderLabel, appearanceHeaderLabel, favoritesHeaderLabel].forEach { headerLabel in
                headerLabel?.textColor = .gray
            }
            
            // Update text field
            usernameTextField.textColor = .black
            usernameTextField.attributedPlaceholder = NSAttributedString(
                string: usernameTextField.placeholder ?? "Enter username",
                attributes: [NSAttributedString.Key.foregroundColor: UIColor.darkGray]
            )
            
            // Update table view if it exists
            favoritesTableView?.reloadData()
        }
    }
    
    @objc private func dismissKeyboard() {
        view.endEditing(true)
    }
    
    @objc private func keyboardWillShow(notification: NSNotification) {
        if let keyboardSize = (notification.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? NSValue)?.cgRectValue {
            if self.view.frame.origin.y == 0 {
                self.view.frame.origin.y -= keyboardSize.height / 4
            }
        }
    }
    
    @objc private func keyboardWillHide(notification: NSNotification) {
        if self.view.frame.origin.y != 0 {
            self.view.frame.origin.y = 0
        }
    }
    
    // MARK: - Theme Management
    // Note: The applyTheme method is implemented higher in the file
}

// MARK: - UITableViewDataSource & UITableViewDelegate
extension ProfileViewController: UITableViewDataSource, UITableViewDelegate {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return favoritesManager.getAllFavorites().count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "FavoriteCell", for: indexPath)
        let favorites = favoritesManager.getAllFavorites()
        
        if indexPath.row < favorites.count {
            let teamPlayer = favorites[indexPath.row]
            
            // Configure the cell
            cell.textLabel?.text = teamPlayer.name
            cell.imageView?.image = teamPlayer.image
            cell.imageView?.layer.cornerRadius = 15
            cell.imageView?.clipsToBounds = true
            
            // Add a remove button
            let removeButton = UIButton(type: .system)
            removeButton.setImage(UIImage(systemName: "heart.fill"), for: .normal)
            removeButton.tintColor = .systemPink
            removeButton.frame = CGRect(x: 0, y: 0, width: 24, height: 24)
            removeButton.tag = indexPath.row
            removeButton.addTarget(self, action: #selector(removeFavorite), for: .touchUpInside)
            cell.accessoryView = removeButton
            
            // Apply current theme to the cell
            if darkModeSwitch.isOn {
                cell.backgroundColor = .systemGray5
                cell.textLabel?.textColor = .white
            } else {
                cell.backgroundColor = .white
                cell.textLabel?.textColor = .black
            }
        }
        
        return cell
    }
    
    @objc private func removeFavorite(_ sender: UIButton) {
        let index = sender.tag
        let favorites = favoritesManager.getAllFavorites()
        
        if index < favorites.count {
            let teamPlayer = favorites[index]
            _ = favoritesManager.toggleFavorite(teamPlayer: teamPlayer)
            // setupFavoritesSection will be called via the notification
        }
    }
}

// MARK: - UITextFieldDelegate
extension ProfileViewController: UITextFieldDelegate {
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        textField.resignFirstResponder()
        return true
    }
    
    func textFieldDidEndEditing(_ textField: UITextField) {
        if textField == usernameTextField {
            // Save username when done editing
            userDefaults.set(textField.text, forKey: usernameKey)
            
            // Notify other view controllers about username change
            NotificationCenter.default.post(name: usernameChangedNotification, object: nil)
        }
    }
    
    // MARK: - Timezone Helper Methods
    
    private func setupTimezonePicker() {
        // Create a container view for the timezone section
        let timezoneContainer = UIView()
        timezoneContainer.translatesAutoresizingMaskIntoConstraints = false
        timezoneContainer.backgroundColor = .clear
        appearanceSectionView.addSubview(timezoneContainer)
        
        // Add a title label for the timezone section
        let titleLabel = UILabel()
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.text = "Time Zone:"
        titleLabel.font = UIFont.systemFont(ofSize: 16, weight: .medium)
        timezoneContainer.addSubview(titleLabel)
        
        // Add the timezone label to show current selection
        timezoneLabel = UILabel()
        timezoneLabel.translatesAutoresizingMaskIntoConstraints = false
        timezoneLabel.text = commonTimezones[selectedTimezoneIndex].0
        timezoneLabel.font = UIFont.systemFont(ofSize: 16)
        timezoneLabel.textAlignment = .right
        timezoneContainer.addSubview(timezoneLabel)
        
        // Create picker view
        timezonePicker = UIPickerView()
        timezonePicker.translatesAutoresizingMaskIntoConstraints = false
        timezonePicker.delegate = self
        timezonePicker.dataSource = self
        appearanceSectionView.addSubview(timezonePicker)
        
        // Position the timezone container below the dark mode switch
        NSLayoutConstraint.activate([
            timezoneContainer.topAnchor.constraint(equalTo: darkModeSwitch.bottomAnchor, constant: 16),
            timezoneContainer.leadingAnchor.constraint(equalTo: appearanceSectionView.leadingAnchor, constant: 16),
            timezoneContainer.trailingAnchor.constraint(equalTo: appearanceSectionView.trailingAnchor, constant: -16),
            timezoneContainer.heightAnchor.constraint(equalToConstant: 30),
            
            titleLabel.leadingAnchor.constraint(equalTo: timezoneContainer.leadingAnchor),
            titleLabel.centerYAnchor.constraint(equalTo: timezoneContainer.centerYAnchor),
            
            timezoneLabel.trailingAnchor.constraint(equalTo: timezoneContainer.trailingAnchor),
            timezoneLabel.centerYAnchor.constraint(equalTo: timezoneContainer.centerYAnchor),
            
            timezonePicker.topAnchor.constraint(equalTo: timezoneContainer.bottomAnchor, constant: 8),
            timezonePicker.leadingAnchor.constraint(equalTo: appearanceSectionView.leadingAnchor),
            timezonePicker.trailingAnchor.constraint(equalTo: appearanceSectionView.trailingAnchor),
            timezonePicker.heightAnchor.constraint(equalToConstant: 120)
        ])
        
        // Select default timezone
        timezonePicker.selectRow(selectedTimezoneIndex, inComponent: 0, animated: false)
    }
    
    private func updateTimezoneLabel() {
        timezoneLabel.text = commonTimezones[selectedTimezoneIndex].0
    }
    
    // MARK: - UIPickerViewDataSource
    func numberOfComponents(in pickerView: UIPickerView) -> Int {
        return 1
    }
    
    func pickerView(_ pickerView: UIPickerView, numberOfRowsInComponent component: Int) -> Int {
        return commonTimezones.count
    }
    
    // MARK: - UIPickerViewDelegate
    func pickerView(_ pickerView: UIPickerView, titleForRow row: Int, forComponent component: Int) -> String? {
        return commonTimezones[row].0
    }
    
    func pickerView(_ pickerView: UIPickerView, didSelectRow row: Int, inComponent component: Int) {
        selectedTimezoneIndex = row
        let timezoneIdentifier = commonTimezones[row].1
        userDefaults.set(timezoneIdentifier, forKey: timezoneKey)
        updateTimezoneLabel()
        
        // Notify other view controllers about timezone change
        NotificationCenter.default.post(name: timezoneChangedNotification, object: nil, userInfo: ["timezone": timezoneIdentifier])
    }
}
