import SwiftUI

struct QuixoteFlowLayout: Layout {
    var spacing: CGFloat = 10
    var rowSpacing: CGFloat = 10

    func sizeThatFits(
        proposal: ProposedViewSize,
        subviews: Subviews,
        cache: inout ()
    ) -> CGSize {
        let maxWidth = proposal.width ?? .infinity
        let rows = makeRows(maxWidth: maxWidth, subviews: subviews)
        return measuredSize(for: rows)
    }

    func placeSubviews(
        in bounds: CGRect,
        proposal: ProposedViewSize,
        subviews: Subviews,
        cache: inout ()
    ) {
        let rows = makeRows(maxWidth: bounds.width, subviews: subviews)
        var y = bounds.minY

        for row in rows {
            var x = bounds.minX
            let rowHeight = row.map(\.size.height).max() ?? 0

            for element in row {
                element.subview.place(
                    at: CGPoint(x: x, y: y),
                    anchor: .topLeading,
                    proposal: ProposedViewSize(element.size)
                )
                x += element.size.width + spacing
            }

            y += rowHeight + rowSpacing
        }
    }

    private func makeRows(
        maxWidth: CGFloat,
        subviews: Subviews
    ) -> [[LayoutElement]] {
        let measured = subviews.map { subview in
            LayoutElement(subview: subview, size: subview.sizeThatFits(.unspecified))
        }

        guard maxWidth.isFinite else {
            return measured.isEmpty ? [] : [measured]
        }

        var rows: [[LayoutElement]] = []
        var currentRow: [LayoutElement] = []
        var currentWidth: CGFloat = 0

        for element in measured {
            let proposedWidth = currentRow.isEmpty
                ? element.size.width
                : currentWidth + spacing + element.size.width

            if !currentRow.isEmpty && proposedWidth > maxWidth {
                rows.append(currentRow)
                currentRow = [element]
                currentWidth = element.size.width
            } else {
                currentRow.append(element)
                currentWidth = proposedWidth
            }
        }

        if !currentRow.isEmpty {
            rows.append(currentRow)
        }

        return rows
    }

    private func rowWidth(for row: [LayoutElement]) -> CGFloat {
        guard !row.isEmpty else { return 0 }
        var contentWidth: CGFloat = 0
        for element in row {
            contentWidth += element.size.width
        }
        let gapWidth = spacing * CGFloat(max(0, row.count - 1))
        return contentWidth + gapWidth
    }

    private func rowHeight(for row: [LayoutElement]) -> CGFloat {
        var tallest: CGFloat = 0
        for element in row {
            tallest = max(tallest, element.size.height)
        }
        return tallest
    }

    private func measuredSize(for rows: [[LayoutElement]]) -> CGSize {
        var width: CGFloat = 0
        var height: CGFloat = 0

        for index in rows.indices {
            let row = rows[index]
            width = max(width, rowWidth(for: row))
            height += rowHeight(for: row)
            if index < rows.count - 1 {
                height += rowSpacing
            }
        }

        return CGSize(width: width, height: height)
    }

    private struct LayoutElement {
        let subview: LayoutSubview
        let size: CGSize
    }
}
