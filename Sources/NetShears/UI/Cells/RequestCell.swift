//
//  RequestCell.swift
//  NetShears
//
//  Created by Mehdi Mirzaie on 6/5/21.
//
//

import UIKit

final class RequestCell: UICollectionViewCell {

    @IBOutlet weak var methodLabel: NSLabel!
    @IBOutlet weak var codeLabel: NSLabel!
    @IBOutlet weak var urlLabel: NSLabel!
    @IBOutlet weak var durationLabel: NSLabel!
    @IBOutlet weak var queryName: UILabel!
    @IBOutlet weak var operationType: UILabel!

    private enum Layout {
        static let verticalPadding: CGFloat = 16
        static let horizontalPadding: CGFloat = 16
        static let leftColumnWidth: CGFloat = 80
        static let columnSpacing: CGFloat = 4
        static let rowSpacing: CGFloat = 4
        static let minimumHeight: CGFloat = 76
        static let metadataRowHeight: CGFloat = 20
    }

    override func awakeFromNib() {
        super.awakeFromNib()

        urlLabel.numberOfLines = 0
        urlLabel.lineBreakMode = .byCharWrapping
        urlLabel.setContentHuggingPriority(.defaultLow, for: .vertical)
        urlLabel.setContentCompressionResistancePriority(.required, for: .vertical)

        operationType.setContentHuggingPriority(.required, for: .vertical)
        queryName.setContentHuggingPriority(.required, for: .vertical)
    }

    func populate(request: NetShearsRequestModel?) {
        guard let request else {
            return
        }

        methodLabel.text = request.method.uppercased()
        codeLabel.isHidden = request.code == 0
        codeLabel.text = String(request.code)

        if let operationName = request.graphqlOperationName, !operationName.isEmpty {
            queryName.text = operationName
            queryName.isHidden = false
        } else {
            queryName.text = nil
            queryName.isHidden = true
        }

        if let operationKind = request.graphqlOperationType, !operationKind.isEmpty {
            operationType.text = operationKind.capitalized
            operationType.isHidden = false
        } else {
            operationType.text = nil
            operationType.isHidden = true
        }

        if request.code != 0 {
            var color: UIColor = Colors.HTTPCode.Generic
            switch request.code {
            case 200..<300:
                color = Colors.HTTPCode.Success
            case 300..<400:
                color = Colors.HTTPCode.Redirect
            case 400..<500:
                color = Colors.HTTPCode.ClientError
            case 500..<600:
                color = Colors.HTTPCode.ServerError
            default:
                color = Colors.HTTPCode.Generic
            }
            codeLabel.borderColor = color
            codeLabel.textColor = color
        } else {
            codeLabel.borderColor = Colors.HTTPCode.Generic
            codeLabel.textColor = Colors.HTTPCode.Generic
        }

        urlLabel.text = request.url
        durationLabel.text = request.durationWithSourceLabel
    }

    static func preferredHeight(for request: NetShearsRequestModel, width: CGFloat) -> CGFloat {
        let urlWidth = width - Layout.horizontalPadding - Layout.leftColumnWidth - Layout.columnSpacing
        var rightHeight: CGFloat = 0

        if let type = request.graphqlOperationType, !type.isEmpty {
            rightHeight += Layout.metadataRowHeight + Layout.rowSpacing
        }
        if let name = request.graphqlOperationName, !name.isEmpty {
            rightHeight += Layout.metadataRowHeight + Layout.rowSpacing
        }

        let urlFont = UIFont.systemFont(ofSize: 15)
        let urlHeight = (request.url as NSString).boundingRect(
            with: CGSize(width: urlWidth, height: .greatestFiniteMagnitude),
            options: [.usesLineFragmentOrigin, .usesFontLeading],
            attributes: [.font: urlFont],
            context: nil
        ).height

        rightHeight += ceil(urlHeight)

        let leftHeight = Layout.metadataRowHeight * 3 + Layout.rowSpacing * 2
        return max(max(leftHeight, rightHeight) + Layout.verticalPadding, Layout.minimumHeight)
    }
}
