import UIKit

final class ViewController: UIViewController {
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        let scroll = UIScrollView()
        let stack = UIStackView()
        scroll.translatesAutoresizingMaskIntoConstraints = false
        stack.translatesAutoresizingMaskIntoConstraints = false
        stack.axis = .vertical
        stack.spacing = 20
        stack.alignment = .fill
        view.addSubview(scroll)
        scroll.addSubview(stack)
        let preferredWidth = stack.widthAnchor.constraint(equalTo: scroll.frameLayoutGuide.widthAnchor, constant: -48)
        preferredWidth.priority = .defaultHigh
        NSLayoutConstraint.activate([
            scroll.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            scroll.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor),
            scroll.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scroll.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            stack.topAnchor.constraint(equalTo: scroll.contentLayoutGuide.topAnchor, constant: 28),
            stack.bottomAnchor.constraint(equalTo: scroll.contentLayoutGuide.bottomAnchor, constant: -28),
            stack.centerXAnchor.constraint(equalTo: scroll.frameLayoutGuide.centerXAnchor),
            stack.leadingAnchor.constraint(greaterThanOrEqualTo: scroll.contentLayoutGuide.leadingAnchor, constant: 24),
            stack.trailingAnchor.constraint(lessThanOrEqualTo: scroll.contentLayoutGuide.trailingAnchor, constant: -24),
            stack.widthAnchor.constraint(lessThanOrEqualToConstant: 560),
            scroll.contentLayoutGuide.widthAnchor.constraint(equalTo: scroll.frameLayoutGuide.widthAnchor),
            preferredWidth
        ])
        let icon = UIImageView(image: UIImage(named: "LargeIcon"))
        icon.contentMode = .scaleAspectFit
        icon.heightAnchor.constraint(equalToConstant: 96).isActive = true
        icon.isAccessibilityElement = false
        stack.addArrangedSubview(icon)
        addLabel("Paste Amendment", style: .largeTitle, to: stack, heading: true)
        addLabel("Paste into websites that block it.", style: .title3, to: stack)
        addLabel("Enable in Safari", style: .title2, to: stack, heading: true)
        addLabel("1. Open Settings, find Safari, then choose Extensions.", style: .body, to: stack)
        addLabel("2. Turn on Paste Amendment and allow access to the websites where you want it.", style: .body, to: stack)
        addLabel("3. Return to Safari, refresh the webpage, then touch and hold a text field and choose Paste.", style: .body, to: stack)
        addLabel("You can also paste with ⌘V when using a keyboard.", style: .body, to: stack)
        addLabel("Your clipboard is never read, saved, or uploaded. If a custom editor behaves unexpectedly, turn off Paste Amendment for that website.", style: .footnote, to: stack)
        let license = UIButton(type: .system)
        license.setTitle("MIT License", for: .normal)
        license.titleLabel?.font = .preferredFont(forTextStyle: .body)
        license.titleLabel?.adjustsFontForContentSizeCategory = true
        license.heightAnchor.constraint(greaterThanOrEqualToConstant: 44).isActive = true
        license.addTarget(self, action: #selector(showLicense), for: .touchUpInside)
        stack.addArrangedSubview(license)
        addLabel("© 2026 Anand Mandapati", style: .footnote, to: stack)
    }

    private func addLabel(_ text: String, style: UIFont.TextStyle, to stack: UIStackView, heading: Bool = false) {
        let label = UILabel()
        label.text = text
        label.font = .preferredFont(forTextStyle: style)
        label.adjustsFontForContentSizeCategory = true
        label.numberOfLines = 0
        if style == .footnote { label.textColor = .secondaryLabel }
        if heading { label.accessibilityTraits.insert(.header) }
        stack.addArrangedSubview(label)
    }

    @objc private func showLicense() {
        guard let url = Bundle.main.url(forResource: "LICENSE", withExtension: nil),
              let text = try? String(contentsOf: url, encoding: .utf8) else { return }
        let controller = UIViewController()
        controller.title = "MIT License"
        let textView = UITextView()
        textView.text = text
        textView.font = .preferredFont(forTextStyle: .body)
        textView.adjustsFontForContentSizeCategory = true
        textView.isEditable = false
        textView.textContainerInset = UIEdgeInsets(top: 20, left: 16, bottom: 20, right: 16)
        controller.view = textView
        controller.navigationItem.rightBarButtonItem = UIBarButtonItem(barButtonSystemItem: .done, target: self, action: #selector(closeLicense))
        present(UINavigationController(rootViewController: controller), animated: true)
    }

    @objc private func closeLicense() { dismiss(animated: true) }
}
