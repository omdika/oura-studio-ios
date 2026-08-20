import SwiftUI
import CoreImage.CIFilterBuiltins
import PDFKit

struct QRGeneratorView: View {
    @EnvironmentObject private var api: APIService
    @Environment(\.dismiss) private var dismiss

    @State private var products: [Product] = []
    @State private var sizesByProduct: [UUID: [ProductSizeDetail]] = [:]
    @State private var selectedSizeIds: Set<UUID> = []
    @State private var qtyPerSize: [UUID: Int] = [:]
    @State private var isLoading = true
    @State private var searchText = ""

    private var filteredProducts: [Product] {
        if searchText.isEmpty { return products }
        return products.filter { product in
            if product.name.localizedCaseInsensitiveContains(searchText) { return true }
            let sizes = (sizesByProduct[product.id] ?? []).filter { !$0.isArchived }
            return sizes.contains { $0.displayLabel.localizedCaseInsensitiveContains(searchText) }
        }
    }

    private func filteredSizes(for product: Product) -> [ProductSizeDetail] {
        let all = (sizesByProduct[product.id] ?? []).filter { !$0.isArchived }
        guard !searchText.isEmpty, !product.name.localizedCaseInsensitiveContains(searchText) else { return all }
        return all.filter { $0.displayLabel.localizedCaseInsensitiveContains(searchText) }
    }

    private var allSelectableSizes: [ProductSizeDetail] {
        filteredProducts.flatMap { filteredSizes(for: $0) }
    }

    private var allSelectableSelected: Bool {
        !allSelectableSizes.isEmpty && allSelectableSizes.allSatisfy { selectedSizeIds.contains($0.id) }
    }

    private var totalLabelCount: Int {
        selectedSizeIds.reduce(0) { $0 + (qtyPerSize[$1] ?? 1) }
    }
    @State private var isGenerating = false
    @State private var showPrintPreview = false
    @State private var pdfData: Data?

    var body: some View {
        NavigationStack {
            ZStack {
                OuraTheme.Colors.background.ignoresSafeArea()

                if isLoading {
                    ProgressView()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if products.isEmpty {
                    emptyView
                } else if filteredProducts.isEmpty {
                    noResultsView
                } else {
                    productList
                }
            }
            .navigationTitle("Generator QR")
            .navigationBarTitleDisplayMode(.large)
            .searchable(text: $searchText, placement: .navigationBarDrawer(displayMode: .always), prompt: "Cari produk atau ukuran...")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Tutup") { dismiss() }
                        .foregroundStyle(OuraTheme.Colors.accent)
                }
            }
            .safeAreaInset(edge: .bottom) {
                if !selectedSizeIds.isEmpty {
                    bottomBar
                }
            }
        }
        .sheet(isPresented: $showPrintPreview) {
            if let data = pdfData {
                PrintPreviewSheet(pdfData: data, count: totalLabelCount)
            }
        }
        .task { await loadData() }
    }

    // MARK: - Product list

    private var productList: some View {
        List {
            Section {
                Button {
                    if allSelectableSelected {
                        allSelectableSizes.forEach {
                            selectedSizeIds.remove($0.id)
                            qtyPerSize.removeValue(forKey: $0.id)
                        }
                    } else {
                        allSelectableSizes.forEach {
                            selectedSizeIds.insert($0.id)
                            if qtyPerSize[$0.id] == nil { qtyPerSize[$0.id] = 1 }
                        }
                    }
                } label: {
                    HStack {
                        Text(allSelectableSelected ? "Batal Semua" : "Pilih Semua")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(OuraTheme.Colors.accent)
                        Spacer()
                        Image(systemName: allSelectableSelected ? "checkmark.circle.fill" : "circle")
                            .font(.system(size: 18))
                            .foregroundStyle(allSelectableSelected ? OuraTheme.Colors.accent : OuraTheme.Colors.border)
                    }
                }
                .buttonStyle(.plain)
                .listRowBackground(OuraTheme.Colors.surfaceCard)
                .listRowInsets(EdgeInsets(top: 10, leading: 16, bottom: 10, trailing: 16))
            }

            ForEach(filteredProducts) { product in
                let sizes = filteredSizes(for: product)
                if !sizes.isEmpty {
                    Section {
                        ForEach(sizes) { size in
                            let isSelected = selectedSizeIds.contains(size.id)
                            let qty = qtyPerSize[size.id] ?? 1
                            HStack(spacing: 12) {
                                if let img = makeQRImage(for: size.id) {
                                    Image(uiImage: img)
                                        .interpolation(.none)
                                        .resizable()
                                        .frame(width: 44, height: 44)
                                        .clipShape(RoundedRectangle(cornerRadius: 6))
                                }
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(size.displayLabel)
                                        .font(.system(size: 14, weight: .medium))
                                        .foregroundStyle(OuraTheme.Colors.textPrimary)
                                    Text("Stok: \(size.currentStockQty) pcs")
                                        .font(.system(size: 12))
                                        .foregroundStyle(OuraTheme.Colors.textTertiary)
                                }
                                Spacer()
                                if isSelected {
                                    HStack(spacing: 2) {
                                        Button {
                                            let newQty = max(1, qty - 1)
                                            qtyPerSize[size.id] = newQty
                                        } label: {
                                            Image(systemName: "minus")
                                                .font(.system(size: 12, weight: .semibold))
                                                .frame(width: 28, height: 28)
                                                .background(OuraTheme.Colors.surfaceSheet)
                                                .clipShape(Circle())
                                                .foregroundStyle(qty > 1 ? OuraTheme.Colors.textPrimary : OuraTheme.Colors.textDisabled)
                                        }
                                        .buttonStyle(.plain)
                                        .disabled(qty <= 1)

                                        Text("\(qty)")
                                            .font(.system(size: 14, weight: .semibold))
                                            .foregroundStyle(OuraTheme.Colors.accent)
                                            .frame(minWidth: 26, alignment: .center)

                                        Button {
                                            qtyPerSize[size.id] = qty + 1
                                        } label: {
                                            Image(systemName: "plus")
                                                .font(.system(size: 12, weight: .semibold))
                                                .frame(width: 28, height: 28)
                                                .background(OuraTheme.Colors.surfaceSheet)
                                                .clipShape(Circle())
                                                .foregroundStyle(OuraTheme.Colors.textPrimary)
                                        }
                                        .buttonStyle(.plain)
                                    }
                                    .padding(.trailing, 4)
                                }
                                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                                    .font(.system(size: 22))
                                    .foregroundStyle(isSelected ? OuraTheme.Colors.accent : OuraTheme.Colors.border)
                            }
                            .contentShape(Rectangle())
                            .onTapGesture {
                                if isSelected {
                                    selectedSizeIds.remove(size.id)
                                    qtyPerSize.removeValue(forKey: size.id)
                                } else {
                                    selectedSizeIds.insert(size.id)
                                    qtyPerSize[size.id] = 1
                                }
                            }
                            .listRowBackground(OuraTheme.Colors.surfaceCard)
                            .listRowInsets(EdgeInsets(top: 10, leading: 16, bottom: 10, trailing: 16))
                        }

                        let allSelected = sizes.allSatisfy { selectedSizeIds.contains($0.id) }
                        Button {
                            if allSelected {
                                sizes.forEach {
                                    selectedSizeIds.remove($0.id)
                                    qtyPerSize.removeValue(forKey: $0.id)
                                }
                            } else {
                                sizes.forEach {
                                    selectedSizeIds.insert($0.id)
                                    if qtyPerSize[$0.id] == nil { qtyPerSize[$0.id] = 1 }
                                }
                            }
                        } label: {
                            Text(allSelected ? "Batal pilih semua" : "Pilih semua ukuran")
                                .font(.system(size: 13, weight: .medium))
                                .foregroundStyle(OuraTheme.Colors.accent)
                        }
                        .buttonStyle(.plain)
                        .listRowBackground(OuraTheme.Colors.surfaceCard)
                        .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                    } header: {
                        Text(product.name)
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(OuraTheme.Colors.textSecondary)
                            .textCase(.none)
                    }
                    .listSectionSeparatorTint(OuraTheme.Colors.separator)
                }
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .background(OuraTheme.Colors.background)
    }

    // MARK: - Bottom bar

    private var bottomBar: some View {
        VStack(spacing: 0) {
            Divider().overlay(OuraTheme.Colors.separator)
            HStack {
                Text("\(totalLabelCount) label · \(selectedSizeIds.count) varian")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(OuraTheme.Colors.textSecondary)
                Spacer()
                Button {
                    Task { await preparePDF() }
                } label: {
                    HStack(spacing: 6) {
                        if isGenerating {
                            ProgressView().scaleEffect(0.8).tint(.white)
                        } else {
                            Image(systemName: "printer")
                                .font(.system(size: 13, weight: .semibold))
                            Text("Preview & Print")
                                .font(.system(size: 14, weight: .semibold))
                        }
                    }
                    .foregroundStyle(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(OuraTheme.Colors.accentGradient)
                    .clipShape(Capsule())
                }
                .buttonStyle(.plain)
                .disabled(isGenerating)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
        .background(OuraTheme.Colors.background)
    }

    private var emptyView: some View {
        VStack(spacing: 12) {
            Image(systemName: "qrcode")
                .font(.system(size: 40))
                .foregroundStyle(OuraTheme.Colors.textTertiary)
            Text("Belum ada produk")
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(OuraTheme.Colors.textSecondary)
            Text("Tambahkan produk di Tab Produk terlebih dahulu")
                .font(.system(size: 13))
                .foregroundStyle(OuraTheme.Colors.textTertiary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var noResultsView: some View {
        VStack(spacing: 12) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 40))
                .foregroundStyle(OuraTheme.Colors.textTertiary)
            Text("Tidak ada hasil")
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(OuraTheme.Colors.textSecondary)
            Text("Coba kata kunci lain")
                .font(.system(size: 13))
                .foregroundStyle(OuraTheme.Colors.textTertiary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - QR generation

    private func makeQRImage(for sizeId: UUID) -> UIImage? {
        let context = CIContext()
        let filter = CIFilter.qrCodeGenerator()
        filter.message = Data("oura:\(sizeId.uuidString)".utf8)
        filter.correctionLevel = "M"
        guard let output = filter.outputImage else { return nil }
        let scaled = output.transformed(by: CGAffineTransform(scaleX: 10, y: 10))
        guard let cgImg = context.createCGImage(scaled, from: scaled.extent) else { return nil }
        return UIImage(cgImage: cgImg)
    }

    // MARK: - PDF generation

    private func preparePDF() async {
        isGenerating = true
        defer { isGenerating = false }

        var repeatedIds: [UUID] = []
        for id in selectedSizeIds {
            let qty = qtyPerSize[id] ?? 1
            repeatedIds.append(contentsOf: Array(repeating: id, count: qty))
        }
        let allSizes = sizesByProduct.values.flatMap { $0 }

        let data = await Task.detached(priority: .userInitiated) {
            Self.generatePDF(for: repeatedIds, sizes: Array(allSizes))
        }.value

        pdfData = data
        showPrintPreview = true
    }

    private nonisolated static func generatePDF(for sizeIds: [UUID], sizes: [ProductSizeDetail]) -> Data {
        let pageRect = CGRect(x: 0, y: 0, width: 595.28, height: 841.89)
        let renderer = UIGraphicsPDFRenderer(bounds: pageRect)

        let mmToPt: CGFloat = 72.0 / 25.4
        let qrSize: CGFloat = 18 * mmToPt  // 1.8 cm ≈ 51 pt
        let labelH: CGFloat = 18
        let cellH = qrSize + labelH + 4
        let margin: CGFloat = 2 * mmToPt   // 2 mm ≈ 5.67 pt
        let gap: CGFloat = 0.5 * mmToPt    // 0.5 mm ≈ 1.42 pt
        let colSpacing: CGFloat = gap
        let rowSpacing: CGFloat = gap
        let cols = Int((pageRect.width - 2 * margin + gap) / (qrSize + gap)) // 11 on A4

        return renderer.pdfData { ctx in
            var col = 0
            var currentY: CGFloat = margin
            ctx.beginPage()

            for sizeId in sizeIds {
                guard let size = sizes.first(where: { $0.id == sizeId }) else { continue }

                if currentY + cellH > pageRect.height - margin {
                    col = 0
                    currentY = margin
                    ctx.beginPage()
                }

                let x = margin + CGFloat(col) * (qrSize + colSpacing)

                let ciCtx = CIContext()
                let filter = CIFilter.qrCodeGenerator()
                filter.message = Data("oura:\(sizeId.uuidString)".utf8)
                filter.correctionLevel = "M"
                if let output = filter.outputImage {
                    let scaled = output.transformed(by: CGAffineTransform(scaleX: 12, y: 12))
                    if let cgImg = ciCtx.createCGImage(scaled, from: scaled.extent) {
                        UIImage(cgImage: cgImg).draw(in: CGRect(x: x, y: currentY, width: qrSize, height: qrSize))
                    }
                }

                // Build 3-line caption: product name / fabric variant / size label
                var captionParts = [size.productName]
                if let fabric = size.fabricVariantName { captionParts.append(fabric) }
                captionParts.append(size.sizeLabel)
                let label = captionParts.joined(separator: "\n")

                let ps = NSMutableParagraphStyle()
                ps.minimumLineHeight = 6.0
                ps.maximumLineHeight = 6.0
                let attrs: [NSAttributedString.Key: Any] = [
                    .font: UIFont.systemFont(ofSize: 5.5),
                    .foregroundColor: UIColor.black,
                    .paragraphStyle: ps
                ]
                label.draw(
                    with: CGRect(x: x, y: currentY + qrSize + 2, width: qrSize, height: labelH),
                    options: .usesLineFragmentOrigin,
                    attributes: attrs,
                    context: nil
                )

                col += 1
                if col >= cols {
                    col = 0
                    currentY += cellH + rowSpacing
                }
            }
        }
    }

    // MARK: - Load data

    private func loadData() async {
        isLoading = true
        defer { isLoading = false }

        let prods = (try? await api.getProducts()) ?? []
        products = prods.filter { !$0.isArchived }

        for product in products {
            let sizes = (try? await api.getProductSizes(sku: product.sku)) ?? []
            sizesByProduct[product.id] = sizes.filter { !$0.isArchived }
        }
    }
}

// MARK: - Print Preview Sheet

private struct PrintPreviewSheet: View {
    let pdfData: Data
    let count: Int
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            PDFKitView(data: pdfData)
                .ignoresSafeArea(edges: .bottom)
                .background(Color(UIColor.systemGroupedBackground))
                .navigationTitle("\(count) Label QR")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Tutup") { dismiss() }
                            .foregroundStyle(OuraTheme.Colors.accent)
                    }
                    ToolbarItem(placement: .primaryAction) {
                        Button {
                            sharePDF()
                        } label: {
                            Label("Print", systemImage: "printer.fill")
                        }
                        .foregroundStyle(OuraTheme.Colors.accent)
                    }
                }
        }
    }

    private func sharePDF() {
        let tmpURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("oura-qr-labels.pdf")
        guard (try? pdfData.write(to: tmpURL)) != nil else { return }

        let activityVC = UIActivityViewController(activityItems: [tmpURL], applicationActivities: nil)

        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let rootVC = windowScene.windows.first?.rootViewController else { return }
        var topVC = rootVC
        while let presented = topVC.presentedViewController { topVC = presented }

        if let popover = activityVC.popoverPresentationController {
            popover.sourceView = topVC.view
            popover.sourceRect = CGRect(
                x: topVC.view.bounds.midX, y: topVC.view.bounds.midY,
                width: 0, height: 0
            )
        }
        topVC.present(activityVC, animated: true)
    }
}

// MARK: - PDFKit wrapper

private struct PDFKitView: UIViewRepresentable {
    let data: Data

    func makeUIView(context: Context) -> PDFView {
        let pdfView = PDFView()
        pdfView.autoScales = true
        pdfView.displayMode = .singlePageContinuous
        pdfView.displayDirection = .vertical
        pdfView.backgroundColor = UIColor.systemGroupedBackground
        pdfView.document = PDFDocument(data: data)
        return pdfView
    }

    func updateUIView(_ uiView: PDFView, context: Context) {}
}
