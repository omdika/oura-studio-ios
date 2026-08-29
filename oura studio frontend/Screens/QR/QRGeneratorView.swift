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

    @State private var isFilterActive = false
    @State private var filterFrom = Date()
    @State private var filterTo = Date()
    @State private var additionsByVariant: [UUID: Int] = [:]

    init(initialIsFilterActive: Bool = false,
         initialFilterFrom: Date = Date(),
         initialFilterTo: Date = Date(),
         initialSearchText: String = "") {
        _isFilterActive = State(initialValue: initialIsFilterActive)
        _filterFrom = State(initialValue: initialFilterFrom)
        _filterTo = State(initialValue: initialFilterTo)
        _searchText = State(initialValue: initialSearchText)
    }

    private var filteredProducts: [Product] {
        let base: [Product]
        let active = products
        
        let dateFiltered = active.filter { product in
            if isFilterActive {
                let sizes = (sizesByProduct[product.id] ?? []).filter { !$0.isArchived }
                return sizes.contains { additionsByVariant[$0.id] != nil }
            }
            return true
        }

        if searchText.isEmpty {
            base = dateFiltered
        } else {
            base = dateFiltered.filter { product in
                if product.name.localizedCaseInsensitiveContains(searchText) ||
                    product.sku.localizedCaseInsensitiveContains(searchText) {
                    return true
                }
                let sizes = filteredSizes(for: product)
                return !sizes.isEmpty
            }
        }
        return base.sorted { $0.name.localizedCompare($1.name) == .orderedAscending }
    }

    private func filteredSizes(for product: Product) -> [ProductSizeDetail] {
        let baseSizes = sizesByProduct[product.id] ?? []
        let dateFiltered = baseSizes.filter { size in
            !isFilterActive || additionsByVariant[size.id] != nil
        }
        let groups = makeSizeGroups(from: dateFiltered)
        let all = groups.flatMap { $0.displayVariants }
        guard !searchText.isEmpty else { return all }
        
        if product.name.localizedCaseInsensitiveContains(searchText) ||
            product.sku.localizedCaseInsensitiveContains(searchText) {
            return all
        }
        
        return all.filter { size in
            size.displayLabel.localizedCaseInsensitiveContains(searchText) ||
            size.productSku.localizedCaseInsensitiveContains(searchText)
        }
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
        .onChange(of: isFilterActive) { _ in
            Task { await loadData() }
        }
        .task { await loadData() }
    }

    // MARK: - Product list

    private var productList: some View {
        List {
            Section {
                VStack(spacing: 10) {
                    Toggle(isOn: $isFilterActive.animation()) {
                        HStack(spacing: 8) {
                            Image(systemName: "calendar.badge.clock")
                                .font(.system(size: 14))
                                .foregroundStyle(isFilterActive ? OuraTheme.Colors.greenAccent : OuraTheme.Colors.textSecondary)
                            Text("Filter berdasarkan Tanggal Masuk Stok")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(OuraTheme.Colors.textPrimary)
                        }
                    }
                    .tint(OuraTheme.Colors.greenAccent)
                    
                    if isFilterActive {
                        DateRangeField(from: $filterFrom, to: $filterTo) {
                            Task { await loadData() }
                        }
                        .transition(.opacity.combined(with: .move(edge: .top)))
                    }
                }
                .padding(.vertical, 4)
                .listRowBackground(OuraTheme.Colors.surfaceCard)
            }

            if filteredProducts.isEmpty {
                Section {
                    VStack(spacing: 12) {
                        Image(systemName: "magnifyingglass")
                            .font(.system(size: 40))
                            .foregroundStyle(OuraTheme.Colors.textTertiary)
                            .padding(.top, 24)
                        Text("Tidak ada hasil")
                            .font(.system(size: 15, weight: .medium))
                            .foregroundStyle(OuraTheme.Colors.textSecondary)
                        Text("Coba ganti kata kunci pencarian atau matikan/ubah rentang tanggal filter.")
                            .font(.system(size: 13))
                            .foregroundStyle(OuraTheme.Colors.textTertiary)
                            .multilineTextAlignment(.center)
                            .padding(.bottom, 24)
                    }
                    .frame(maxWidth: .infinity, alignment: .center)
                    .listRowBackground(OuraTheme.Colors.surfaceCard)
                }
            } else {
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
                                if qtyPerSize[$0.id] == nil {
                                    if isFilterActive {
                                        qtyPerSize[$0.id] = additionsByVariant[$0.id] ?? 1
                                    } else {
                                        qtyPerSize[$0.id] = max(1, $0.currentStockQty)
                                    }
                                }
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
                                        if isFilterActive {
                                            qtyPerSize[size.id] = additionsByVariant[size.id] ?? 1
                                        } else {
                                            qtyPerSize[size.id] = max(1, size.currentStockQty)
                                        }
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
                                        if qtyPerSize[$0.id] == nil {
                                            if isFilterActive {
                                                qtyPerSize[$0.id] = additionsByVariant[$0.id] ?? 1
                                            } else {
                                                qtyPerSize[$0.id] = max(1, $0.currentStockQty)
                                            }
                                        }
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

        let allSizes = sizesByProduct.values.flatMap { $0 }
        let sortedSelected = allSizes
            .filter { selectedSizeIds.contains($0.id) }
            .sorted {
                let nameCmp = $0.productName.localizedCompare($1.productName)
                if nameCmp != .orderedSame { return nameCmp == .orderedAscending }
                return $0.displayLabel.localizedCompare($1.displayLabel) == .orderedAscending
            }

        var repeatedIds: [UUID] = []
        for size in sortedSelected {
            let qty = qtyPerSize[size.id] ?? 1
            repeatedIds.append(contentsOf: Array(repeating: size.id, count: qty))
        }

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
        // SKU line (smaller font) directly under the QR code, then the product-name/fabric/size
        // caption below it. The caption box is always sized for the worst case -- 3 lines (product
        // name, jenis kain, ukuran) -- and kept that size even for 2-line items (no jenis kain).
        // Critically, captionBoxH also adds a flat buffer ON TOP of the exact lines×lineHeight
        // total, not just the lines×lineHeight itself -- String.draw(with:CGRect...) hard-clips to
        // the given rect, and an *exactly*-sized box (zero headroom) reliably clips the descenders
        // of the last line even when the paragraph style's forced line height should "fit" on paper.
        // That's why the 2-line case (no jenis kain) was fine even before this buffer was added
        // (it had slack from being sized for the 3-line worst case) while the 3-line case, which
        // used up the whole box exactly, kept dropping "ukuran" until this buffer was added too.
        let skuFontSize: CGFloat = 4.5
        let skuLineH: CGFloat = 0.0
        let captionFontSize: CGFloat = 4.5
        let captionLineH: CGFloat = 5.5
        let maxCaptionLines = 5
        let captionBoxH: CGFloat = CGFloat(maxCaptionLines) * captionLineH + 6
        let labelH: CGFloat = skuLineH + captionBoxH
        let cellH = qrSize + labelH + 6
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

                // SKU separate drawing is removed to prevent duplication. SKU is now included directly in the caption label.
                let skuY = currentY + qrSize + 2

                // Caption: SKU - Product Name - Size - Fabric Variant (if any) / SKU - Product Name - Size (if none).
                // Always drawn into the same fixed-size captionBoxH.
                let label: String
                if let fabric = size.fabricVariantName {
                    label = "\(size.productSku) - \(size.productName) - \(size.sizeLabel) - \(fabric)"
                } else {
                    label = "\(size.productSku) - \(size.productName) - \(size.sizeLabel)"
                }

                let ps = NSMutableParagraphStyle()
                ps.minimumLineHeight = captionLineH
                ps.maximumLineHeight = captionLineH
                let attrs: [NSAttributedString.Key: Any] = [
                    .font: UIFont.systemFont(ofSize: captionFontSize),
                    .foregroundColor: UIColor.black,
                    .paragraphStyle: ps
                ]
                label.draw(
                    with: CGRect(x: x, y: skuY + skuLineH, width: qrSize, height: captionBoxH),
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

        let allSizes = (try? await api.getAllProductSizes()) ?? []
        let activeSizes = allSizes.filter { !$0.isArchived }
        sizesByProduct = Dictionary(grouping: activeSizes, by: { $0.productId })
        
        var ledgerAdditions: [UUID: Int] = [:]
        if isFilterActive {
            do {
                let entries = try await api.getStockLedger(from: filterFrom, to: filterTo)
                // Group all entries by size, sum all changes (positive and negative) to get the net addition,
                // and keep only those sizes that had a net positive stock increase in this period.
                ledgerAdditions = Dictionary(grouping: entries, by: { $0.productSizeId })
                    .mapValues { entries in entries.reduce(0) { $0 + $1.changeQty } }
                    .filter { $0.value > 0 }
            } catch {
                print("⚠️ [v3.44] Gagal memuat stock ledger dari backend: \(error)")
            }
        }
        additionsByVariant = ledgerAdditions
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
