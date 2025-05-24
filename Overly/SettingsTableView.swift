import AppKit

class SettingsTableView: NSView {

    internal let stackView: NSStackView = {
        let stackView = NSStackView()
        stackView.orientation = .vertical
        stackView.alignment = .leading // Align rows to the leading edge
        stackView.spacing = 10 // Adjust spacing between rows as needed
        stackView.distribution = .fill // Make the stack view fill available space
        stackView.translatesAutoresizingMaskIntoConstraints = false
        return stackView
    }()

    // Define a fixed width for labels to ensure alignment. Adjust as needed.
    private let labelWidth: CGFloat = 150

    override init(frame: NSRect) {
        super.init(frame: frame)
        setupViews()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupViews()
    }

    private func setupViews() {
        addSubview(stackView)

        NSLayoutConstraint.activate([
            stackView.topAnchor.constraint(equalTo: topAnchor),
            stackView.leadingAnchor.constraint(equalTo: leadingAnchor),
            stackView.trailingAnchor.constraint(equalTo: trailingAnchor),
            stackView.bottomAnchor.constraint(lessThanOrEqualTo: bottomAnchor) // Allow content to not fill the entire height
        ])
    }

    /// Adds a new row to the settings table.
    /// - Parameters:
    ///   - labelText: The text for the label on the left.
    ///   - control: The NSControl (or any NSView) to place on the right.
    func addRow(labelText: String, control: NSView) {
        let rowStackView = NSStackView()
        rowStackView.orientation = .horizontal
        rowStackView.alignment = .centerY // Vertically align label and control
        rowStackView.spacing = 10 // Adjust spacing between label and control
        rowStackView.translatesAutoresizingMaskIntoConstraints = false

        let label = NSTextField(labelWithString: labelText)
        label.alignment = .right // Align label text to the right
        label.translatesAutoresizingMaskIntoConstraints = false
        label.setContentHuggingPriority(.defaultHigh, for: .horizontal)
        label.setContentCompressionResistancePriority(.defaultHigh, for: .horizontal)

        // Set a fixed width or potentially use constraints to ensure alignment
        label.widthAnchor.constraint(equalToConstant: labelWidth).isActive = true

        // Allow the control to take up remaining space and hug its content
        control.setContentHuggingPriority(.defaultLow, for: .horizontal)
        control.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)

        rowStackView.addArrangedSubview(label)
        rowStackView.addArrangedSubview(control)

        stackView.addArrangedSubview(rowStackView)
    }

    // Example usage (you would call addRow for each setting you want)
    func addExampleRows() {
        // Username row
        let usernameTextField = NSTextField()
        usernameTextField.placeholderString = "Enter your username"
        usernameTextField.translatesAutoresizingMaskIntoConstraints = false
        addRow(labelText: "Username:", control: usernameTextField)

        // Enable Notifications row
        let notificationsSwitch = NSSwitch()
        notificationsSwitch.controlSize = .small // Use a smaller switch size if preferred
        notificationsSwitch.state = .on // Set initial state
        notificationsSwitch.translatesAutoresizingMaskIntoConstraints = false
        addRow(labelText: "Enable Notifications:", control: notificationsSwitch)

        // Theme row
        let themePopUpButton = NSPopUpButton()
        themePopUpButton.addItems(withTitles: ["Light", "Dark", "System"])
        themePopUpButton.translatesAutoresizingMaskIntoConstraints = false
        addRow(labelText: "Theme:", control: themePopUpButton)

        // Add a spacer to push content to the top
        let spacer = NSView()
        spacer.translatesAutoresizingMaskIntoConstraints = false
        stackView.addArrangedSubview(spacer)
        stackView.setViews([spacer], in: .bottom)
        spacer.setContentHuggingPriority(.defaultLow, for: .vertical)
    }
}

// You would integrate this NSView into your window/view controller.
// If using SwiftUI, you would wrap this using NSViewRepresentable. 