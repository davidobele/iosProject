//
//  FeedViewController.swift
//  Planter
//
//  Created by David Obele on 4/15/25.
//

import UIKit

// MARK: - Models
struct FixtureResponse: Codable {
    let response: [Fixture]? // Make this optional to fix the error
    let errors: [String: String]?
}

struct Fixture: Codable {
    let fixture: FixtureInfo
    let league: League
    let teams: Teams
    let venue: Venue?
    
    // Computed property to make sorting easier
    var startTime: Date? {
        let formatter = ISO8601DateFormatter()
        return formatter.date(from: fixture.date)
    }
}

struct FixtureInfo: Codable {
    let id: Int
    let date: String
    let status: FixtureStatus
}

struct FixtureStatus: Codable {
    let long: String
    let short: String
}

struct League: Codable {
    let id: Int
    let name: String
    let logo: String
}

struct Teams: Codable {
    let home: Team
    let away: Team
}

struct Team: Codable {
    let id: Int
    let name: String
    let logo: String
}

struct Venue: Codable {
    let name: String
    let city: String?
}

class FeedViewController: UIViewController {
    
    // MARK: - Outlets
    @IBOutlet weak var welcomeLabel: UILabel!
    @IBOutlet weak var tableView: UITableView!
    @IBOutlet weak var activityIndicator: UIActivityIndicatorView!
    
    // MARK: - Properties
    private let userDefaults = UserDefaults.standard
    private let usernameKey = "username"
    private let timezoneKey = "selectedTimezone"
    
    // Current timezone
    private var currentTimezone: TimeZone = TimeZone.current
    
    // League section data
    private var leagueFixtures: [String: [Fixture]] = [:]
    private var filteredFixtures: [String: [Fixture]] = [:]
    private var leagueNames: [String] = []
    
    // API Constants
    private let apiKey = "bbee80adae41ba0c98f868b361f04b69" // Replace with your API key
    private let baseURL = "https://v3.football.api-sports.io/fixtures"
    private let leagues = [
        (name: "Premier League", id: 39),
        (name: "Brasileirão", id: 71),
        (name: "UEFA Champions League", id: 2)
    ]
    private let useMockData = true // Set to false to use real API
    
    // MARK: - Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        
        setupUI()
        configureTableView()
        
        // Add notification for username changes
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(usernameChanged),
                                               name: NSNotification.Name("UsernameChangedNotification"),
                                               object: nil)
        
        // Add notification for timezone changes
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(timezoneChanged(_:)),
                                               name: NSNotification.Name("TimezoneChangedNotification"),
                                               object: nil)
        
        // Fetch games when view loads
        fetchTodayMatches()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        // Update welcome message with username
        updateWelcomeMessage()
        
        // Load timezone setting
        loadUserTimezone()
        
        // Refresh display with current timezone
        tableView.reloadData()
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    // MARK: - UI Setup
    private func setupUI() {
        // Style the welcome label
        welcomeLabel.font = UIFont.boldSystemFont(ofSize: 20)
        
        // Update welcome message with username
        updateWelcomeMessage()
        
        // Set up activity indicator
        if activityIndicator == nil {
            let indicator = UIActivityIndicatorView(style: .large)
            indicator.translatesAutoresizingMaskIntoConstraints = false
            indicator.hidesWhenStopped = true
            view.addSubview(indicator)
            
            NSLayoutConstraint.activate([
                indicator.centerXAnchor.constraint(equalTo: view.centerXAnchor),
                indicator.centerYAnchor.constraint(equalTo: view.centerYAnchor)
            ])
            
            activityIndicator = indicator
        }
    }
    
    // Segmented control removed
    
    private func configureTableView() {
        // Create table view if it doesn't exist in storyboard
        if tableView == nil {
            let table = UITableView(frame: .zero, style: .grouped)
            table.translatesAutoresizingMaskIntoConstraints = false
            view.addSubview(table)
            
            NSLayoutConstraint.activate([
                table.topAnchor.constraint(equalTo: welcomeLabel.bottomAnchor, constant: 20),
                table.leftAnchor.constraint(equalTo: view.leftAnchor),
                table.rightAnchor.constraint(equalTo: view.rightAnchor),
                table.bottomAnchor.constraint(equalTo: view.bottomAnchor)
            ])
            
            tableView = table
        }
        
        // Configure table view
        tableView.delegate = self
        tableView.dataSource = self
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "FixtureCell")
        tableView.backgroundColor = .systemBackground
    }
    
    // MARK: - Data Handling
    private func fetchTodayMatches() {
        // Show loading indicator
        activityIndicator?.startAnimating()
        
        if useMockData {
            // Use mock data for testing
            DispatchQueue.main.asyncAfter(deadline: .now() + 1) { [weak self] in
                self?.leagueFixtures = self?.createMockData() ?? [:]
                self?.prepareFixturesForDisplay() // Prepare fixtures for display
                self?.leagueNames = self?.filteredFixtures.keys.sorted() ?? []
                self?.tableView.reloadData()
                self?.activityIndicator?.stopAnimating()
            }
            return
        }
        
        // Get today's date formatted as YYYY-MM-DD
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        let today = dateFormatter.string(from: Date())
        
        // Create a dispatch group to wait for all network calls
        let dispatchGroup = DispatchGroup()
        
        // Clear previous data
        leagueFixtures.removeAll()
        
        // Fetch fixtures for each league
        for league in leagues {
            dispatchGroup.enter()
            
            // Create URL with query parameters
            let urlString = "\(baseURL)?date=\(today)&league=\(league.id)&season=2024"
            guard let url = URL(string: urlString) else {
                dispatchGroup.leave()
                continue
            }
            
            // Create and configure request
            var request = URLRequest(url: url)
            request.addValue(apiKey, forHTTPHeaderField: "x-apisports-key")
            
            // Create data task
            let task = URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
                defer { dispatchGroup.leave() }
                
                // Handle errors
                if let error = error {
                    print("Error fetching \(league.name): \(error.localizedDescription)")
                    return
                }
                
                // Check for valid data
                guard let data = data else {
                    print("No data received for \(league.name)")
                    return
                }
                
                // Parse response
                do {
                    let fixtureResponse = try JSONDecoder().decode(FixtureResponse.self, from: data)
                    if let fixtures = fixtureResponse.response, !fixtures.isEmpty {
                        DispatchQueue.main.async {
                            self?.leagueFixtures[league.name] = fixtures
                        }
                    } else {
                        print("No fixtures found for \(league.name) or empty response array")
                    }
                } catch {
                    print("Error parsing \(league.name) data: \(error.localizedDescription)")
                }
            }
            
            task.resume()
        }
        
        // When all requests complete, update UI
        dispatchGroup.notify(queue: .main) { [weak self] in
            self?.prepareFixturesForDisplay() // Prepare fixtures for display
            self?.leagueNames = self?.filteredFixtures.keys.sorted() ?? []
            self?.tableView.reloadData()
            self?.activityIndicator?.stopAnimating()
        }
    }
    
    // Mock data for testing
    private func createMockData() -> [String: [Fixture]] {
        // Create example fixtures
        let premierLeagueFixture = Fixture(
            fixture: FixtureInfo(
                id: 1,
                date: "2025-04-23T19:30:00+00:00",
                status: FixtureStatus(long: "Not Started", short: "NS")
            ),
            league: League(
                id: 39,
                name: "Premier League",
                logo: "https://media.api-sports.io/football/leagues/39.png"
            ),
            teams: Teams(
                home: Team(
                    id: 40,
                    name: "Liverpool",
                    logo: "https://media.api-sports.io/football/teams/40.png"
                ),
                away: Team(
                    id: 33,
                    name: "Manchester United",
                    logo: "https://media.api-sports.io/football/teams/33.png"
                )
            ),
            venue: Venue(
                name: "Anfield",
                city: "Liverpool"
            )
        )
        
        let brasileiraoFixture = Fixture(
            fixture: FixtureInfo(
                id: 2,
                date: "2025-04-23T22:00:00+00:00",
                status: FixtureStatus(long: "Not Started", short: "NS")
            ),
            league: League(
                id: 71,
                name: "Brasileirão",
                logo: "https://media.api-sports.io/football/leagues/71.png"
            ),
            teams: Teams(
                home: Team(
                    id: 118,
                    name: "Flamengo",
                    logo: "https://media.api-sports.io/football/teams/118.png"
                ),
                away: Team(
                    id: 130,
                    name: "São Paulo",
                    logo: "https://media.api-sports.io/football/teams/130.png"
                )
            ),
            venue: Venue(
                name: "Maracanã",
                city: "Rio de Janeiro"
            )
        )
        
        let clFixture = Fixture(
            fixture: FixtureInfo(
                id: 3,
                date: "2025-04-23T19:00:00+00:00",
                status: FixtureStatus(long: "Not Started", short: "NS")
            ),
            league: League(
                id: 2,
                name: "UEFA Champions League",
                logo: "https://media.api-sports.io/football/leagues/2.png"
            ),
            teams: Teams(
                home: Team(
                    id: 541,
                    name: "Real Madrid",
                    logo: "https://media.api-sports.io/football/teams/541.png"
                ),
                away: Team(
                    id: 157,
                    name: "Bayern Munich",
                    logo: "https://media.api-sports.io/football/teams/157.png"
                )
            ),
            venue: Venue(
                name: "Santiago Bernabéu",
                city: "Madrid"
            )
        )
        
        return [
            "Premier League": [premierLeagueFixture],
            "Brasileirão": [brasileiraoFixture],
            "UEFA Champions League": [clFixture]
        ]
    }
    
    // MARK: - Helper Methods
    private func updateWelcomeMessage() {
        // Get username from UserDefaults
        if let username = userDefaults.string(forKey: usernameKey), !username.isEmpty {
            welcomeLabel.text = "Hello \(username)!"
        } else {
            welcomeLabel.text = "Hello!"
        }
    }
    
    private func formatMatchTime(_ dateString: String) -> String {
        let formatter = ISO8601DateFormatter()
        guard let date = formatter.date(from: dateString) else {
            return "Time TBD"
        }
        
        // Load timezone from UserDefaults
        loadUserTimezone()
        
        let timeFormatter = DateFormatter()
        timeFormatter.timeZone = currentTimezone
        timeFormatter.dateFormat = "h:mm a"
        
        // Add timezone abbreviation if not using local time
        if currentTimezone.identifier != TimeZone.current.identifier {
            return timeFormatter.string(from: date) + " " + currentTimezone.abbreviation(for: date)!
        } else {
            return timeFormatter.string(from: date)
        }
    }
    
    private func loadUserTimezone() {
        if let timezoneId = userDefaults.string(forKey: timezoneKey),
           let timezone = TimeZone(identifier: timezoneId) {
            currentTimezone = timezone
        } else {
            // Default to device timezone if not set
            currentTimezone = TimeZone.current
        }
    }
    
    private func prepareFixturesForDisplay() {
        // Simply copy all fixtures to filtered fixtures
        filteredFixtures = leagueFixtures
    }
    
    // MARK: - Actions
    @objc private func usernameChanged() {
        updateWelcomeMessage()
    }
    
    @objc private func timezoneChanged(_ notification: Notification) {
        // Update timezone and refresh display
        if let timezoneId = notification.userInfo?["timezone"] as? String,
           let timezone = TimeZone(identifier: timezoneId) {
            currentTimezone = timezone
            // Reload table to update times
            tableView.reloadData()
        }
    }
    
    // Segment control removed
}

// MARK: - TableView DataSource & Delegate
extension FeedViewController: UITableViewDataSource, UITableViewDelegate {
    
    func numberOfSections(in tableView: UITableView) -> Int {
        return leagueNames.count
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        let leagueName = leagueNames[section]
        return filteredFixtures[leagueName]?.count ?? 0
    }
    
    func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        return leagueNames[section]
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "FixtureCell", for: indexPath)
        
        // Get the fixture for this cell
        let leagueName = leagueNames[indexPath.section]
        if let fixtures = filteredFixtures[leagueName], indexPath.row < fixtures.count {
            let fixture = fixtures[indexPath.row]
            
            // Configure cell
            var config = cell.defaultContentConfiguration()
            config.text = "\(fixture.teams.home.name) vs \(fixture.teams.away.name)"
            config.secondaryText = "\(formatMatchTime(fixture.fixture.date)) at \(fixture.venue?.name ?? "TBD")"
            
            cell.contentConfiguration = config
        }
        
        return cell
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        // Future enhancement: Show match details
    }
}
