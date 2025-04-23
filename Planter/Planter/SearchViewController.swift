import UIKit

// MARK: - Model
struct TeamPlayer: Codable, Equatable {
    let name: String
    let imageName: String
    var isFavorite: Bool
    
    // For team logos that are built into the app
    var image: UIImage? {
        return UIImage(named: imageName)
    }
    
    // Required for Codable, but not stored
    enum CodingKeys: String, CodingKey {
        case name, imageName, isFavorite
    }
    
    // Equatable implementation
    static func == (lhs: TeamPlayer, rhs: TeamPlayer) -> Bool {
        return lhs.name == rhs.name
    }
}

class SearchViewController: UIViewController, UISearchBarDelegate, UITableViewDelegate, UITableViewDataSource {
    
    // MARK: - Outlets
    @IBOutlet weak var searchBar: UISearchBar!
    @IBOutlet weak var tableView: UITableView!
    
    // MARK: - Properties
    private var teamPlayers: [TeamPlayer] = [
        TeamPlayer(name: "Arsenal", imageName: "Arsenal", isFavorite: false),
        TeamPlayer(name: "Bayern", imageName: "Bayern", isFavorite: false),
        TeamPlayer(name: "Corinthians", imageName: "Corinthians", isFavorite: false),
        TeamPlayer(name: "Crystal Palace", imageName: "Crystal Palace", isFavorite: false),
        TeamPlayer(name: "Memphis Depay", imageName: "Depay", isFavorite: false),
        TeamPlayer(name: "Fluminense", imageName: "Fluminense", isFavorite: false),
        TeamPlayer(name: "Harry Kane", imageName: "Harry Kane", isFavorite: false),
        TeamPlayer(name: "Inter", imageName: "Inter", isFavorite: false),
        TeamPlayer(name: "Newcastle", imageName: "Newcastle", isFavorite: false),
        TeamPlayer(name: "Real Madrid", imageName: "Real Madrid", isFavorite: false)
    ]
    
    private var filteredTeamPlayers: [TeamPlayer] = []
    
    // Favorites manager
    private let favoritesManager = FavoritesManager.shared
    
    // MARK: - Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Set up delegates
        searchBar.delegate = self
        tableView.delegate = self
        tableView.dataSource = self
        
        // Make sure table view cell has correct identifier
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "TeamPlayerCell")
        
        // Update favorites status from manager
        updateFavoritesStatus()
        
        // Initially show all teams/players
        filteredTeamPlayers = teamPlayers
        
        // Setup UI
        configureUI()
        
        // Listen for favorites changes from other screens
        NotificationCenter.default.addObserver(self, 
                                               selector: #selector(favoritesChanged), 
                                               name: FavoritesManager.favoritesChangedNotification, 
                                               object: nil)
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    @objc private func favoritesChanged() {
        updateFavoritesStatus()
        tableView.reloadData()
    }
    
    private func updateFavoritesStatus() {
        // Update favorite status based on the FavoritesManager
        for i in 0..<teamPlayers.count {
            let isFavorite = favoritesManager.isFavorite(teamPlayer: teamPlayers[i])
            teamPlayers[i].isFavorite = isFavorite
        }
    }
    
    // MARK: - UI Configuration
    private func configureUI() {
        // Make table view cells look cleaner
        tableView.separatorInset = UIEdgeInsets(top: 0, left: 16, bottom: 0, right: 16)
        tableView.tableFooterView = UIView() // Hide empty rows
    }
    
    // MARK: - Actions
    @objc func favoriteButtonTapped(_ sender: UIButton) {
        // Get the index of the tapped row
        let point = sender.convert(CGPoint.zero, to: tableView)
        if let indexPath = tableView.indexPathForRow(at: point) {
            // Get the team player
            let teamPlayer = filteredTeamPlayers[indexPath.row]
            
            // Toggle favorite through the manager
            let isFavorite = favoritesManager.toggleFavorite(teamPlayer: teamPlayer)
            
            // Update our data models
            if let originalIndex = teamPlayers.firstIndex(where: { $0.name == teamPlayer.name }) {
                teamPlayers[originalIndex].isFavorite = isFavorite
            }
            filteredTeamPlayers[indexPath.row].isFavorite = isFavorite
            
            // Update button state
            sender.isSelected = isFavorite
        }
    }
    
    // MARK: - UISearchBarDelegate
    func searchBar(_ searchBar: UISearchBar, textDidChange searchText: String) {
        if searchText.isEmpty {
            filteredTeamPlayers = teamPlayers
        } else {
            filteredTeamPlayers = teamPlayers.filter { $0.name.lowercased().contains(searchText.lowercased()) }
        }
        tableView.reloadData()
    }
    
    func searchBarSearchButtonClicked(_ searchBar: UISearchBar) {
        searchBar.resignFirstResponder()
    }
    
    // MARK: - UITableViewDataSource
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return filteredTeamPlayers.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "TeamPlayerCell", for: indexPath)
        let teamPlayer = filteredTeamPlayers[indexPath.row]
        
        // Configure cell
        configureCellForTeamPlayer(cell, with: teamPlayer)
        
        return cell
    }
    
    private func configureCellForTeamPlayer(_ cell: UITableViewCell, with teamPlayer: TeamPlayer) {
        // Access UI elements using view tags if needed
        if let imageView = cell.contentView.viewWithTag(1) as? UIImageView,
           let nameLabel = cell.contentView.viewWithTag(2) as? UILabel,
           let favoriteButton = cell.contentView.viewWithTag(3) as? UIButton {
            
            // Set image
            imageView.image = teamPlayer.image
            imageView.layer.cornerRadius = 20 // Make the image round
            imageView.clipsToBounds = true
            
            // Set name
            nameLabel.text = teamPlayer.name
            
            // Set favorite button state
            favoriteButton.isSelected = teamPlayer.isFavorite
            favoriteButton.addTarget(self, action: #selector(favoriteButtonTapped(_:)), for: .touchUpInside)
        } else {
            // If there are no tags, we'll need to configure the cell programmatically
            cell.textLabel?.text = teamPlayer.name
            cell.imageView?.image = teamPlayer.image
            cell.imageView?.layer.cornerRadius = 20
            cell.imageView?.clipsToBounds = true
            
            // Add favorite button if it doesn't exist
            let favoriteButton = UIButton(type: .custom) // Change to .custom type for better icon rendering
            
            // Configure the button with heart images
            let config = UIImage.SymbolConfiguration(pointSize: 22, weight: .regular)
            let heartImage = UIImage(systemName: "heart", withConfiguration: config)
            let heartFillImage = UIImage(systemName: "heart.fill", withConfiguration: config)
            
            favoriteButton.setImage(heartImage, for: .normal)
            favoriteButton.setImage(heartFillImage, for: .selected)
            favoriteButton.tintColor = .systemPink
            favoriteButton.frame = CGRect(x: 0, y: 0, width: 36, height: 36)
            favoriteButton.addTarget(self, action: #selector(favoriteButtonTapped(_:)), for: .touchUpInside)
            
            // Set the initial selected state based on favorite status
            favoriteButton.isSelected = teamPlayer.isFavorite
            
            cell.accessoryView = favoriteButton
        }
    }
    
    // MARK: - UITableViewDelegate
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        // Handle selection - can be used to navigate to detail page
    }
}
