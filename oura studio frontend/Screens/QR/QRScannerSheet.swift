import SwiftUI
import VisionKit
import Vision

// MARK: - Scan Mode

enum QRScanMode {
    case any
    case sellOnly
    case stockInOnly
}

// MARK: - Scan State

private enum ScanState: Equatable {
    case scanning
    case resolving
    case resolved(ProductSizeDetail)
    case error(String)

    static func == (lhs: ScanState, rhs: ScanState) -> Bool {
        switch (lhs, rhs) {
        case (.scanning, .scanning):         return true
        case (.resolving, .resolving):       return true
        case (.error(let a), .error(let b)): return a == b
        case (.resolved(let a), .resolved(let b)): return a.id == b.id
        default: return false
        }
    }
}

// MARK: - Cart Item

private struct CartItem: Identifiable {
    let id = UUID()
    let size: ProductSizeDetail
    var qty: Int
    var unitPrice: Double

    init(size: ProductSizeDetail) {
        self.size = size
        self.qty = 1
        self.unitPrice = size.sellingPrice ?? 0
    }
}

// MARK: - Sheet

struct QRScannerSheet: View {
    @EnvironmentObject private var api: APIService
    @EnvironmentObject private var appState: AppState
    @Environment(\.dismiss) private var dismiss

    let mode: QRScanMode

    @State private var scanState: ScanState = .scanning
    @State private var showSellSheet = false
    @State private var showStockSheet = false
    @State private var resolvedSize: ProductSizeDetail? = nil

    // Cart mode (sellOnly)
    @State private var cartItems: [CartItem] = []
    @State private var showCheckoutSheet = false
    @State private var cartToast: String? = nil

    private var isScanning: Bool {
        scanState == .scanning && !showCheckoutSheet
    }

    private var cartTotal: Double {
        cartItems.reduce(0) { $0 + $1.unitPrice * Double($1.qty) }
    }

    private var cartItemCount: Int {
        cartItems.reduce(0) { $0 + $1.qty }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                if DataScannerViewController.isSupported && DataScannerViewController.isAvailable {
                    DataScannerRepresentable(isActive: isScanning, onScan: handleRawScan)
                        .ignoresSafeArea()
                } else {
                    unsupportedView
                }

                if mode == .sellOnly {
                    cartModeOverlay
                } else {
                    VStack {
                        Spacer()
                        bottomOverlay
                            .animation(.easeInOut(duration: 0.25), value: scanState)
                    }
                }
            }
            .navigationTitle(mode == .sellOnly ? "Scan & Jual" : "Scan QR Produk")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Tutup") { dismiss() }
                        .foregroundStyle(OuraTheme.Colors.accent)
                }
            }
        }
        .sheet(isPresented: $showCheckoutSheet) {
            QRCartCheckoutSheet(
                cartItems: $cartItems,
                onSuccess: {
                    appState.dashboardNeedsRefresh = true
                    dismiss()
                }
            )
            .environmentObject(api)
        }
        .sheet(isPresented: $showSellSheet, onDismiss: {
            if scanState != .scanning { scanState = .scanning }
        }) {
            if let size = resolvedSize {
                ScanToSellSheet(size: size, dismissParent: { dismiss() })
                    .environmentObject(api)
            }
        }
        .sheet(isPresented: $showStockSheet, onDismiss: {
            if scanState != .scanning { scanState = .scanning }
        }) {
            if let size = resolvedSize {
                ScanToStockSheet(size: size, dismissParent: { dismiss() })
                    .environmentObject(api)
            }
        }
    }

    // MARK: - Cart mode overlay

    private var cartModeOverlay: some View {
        ZStack(alignment: .top) {
            // Toast at top
            VStack {
                if let toast = cartToast {
                    HStack(spacing: 8) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 14))
                            .foregroundStyle(OuraTheme.Colors.greenAccent)
                        Text(toast)
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(.white)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(Color.black.opacity(0.72))
                    .clipShape(Capsule())
                    .padding(.top, 8)
                    .transition(.move(edge: .top).combined(with: .opacity))
                }
                Spacer()
            }
            .animation(.spring(duration: 0.3), value: cartToast != nil)
            .zIndex(10)

            // Bottom area
            VStack(spacing: 0) {
                Spacer()

                switch scanState {
                case .resolving:
                    resolvingCard
                        .transition(.opacity)
                        .animation(.easeInOut(duration: 0.2), value: scanState)
                case .error(let msg):
                    errorCard(msg)
                        .transition(.opacity)
                        .animation(.easeInOut(duration: 0.2), value: scanState)
                default:
                    EmptyView()
                }

                if cartItems.isEmpty {
                    scanHint
                } else {
                    cartBar
                }
            }
        }
    }

    // MARK: - Cart bar

    private var cartBar: some View {
        Button { showCheckoutSheet = true } label: {
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(OuraTheme.Colors.accent)
                        .frame(width: 34, height: 34)
                    Image(systemName: "cart.fill")
                        .font(.system(size: 14))
                        .foregroundStyle(.white)
                }

                VStack(alignment: .leading, spacing: 1) {
                    Text("\(cartItemCount) item")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(OuraTheme.Colors.textPrimary)
                    Text(cartTotal.rupiahFormatted)
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(OuraTheme.Colors.accent)
                }

                Spacer()

                HStack(spacing: 5) {
                    Text("Checkout")
                        .font(.system(size: 14, weight: .semibold))
                    Image(systemName: "chevron.right")
                        .font(.system(size: 12, weight: .semibold))
                }
                .foregroundStyle(.white)
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(OuraTheme.Colors.accentGradient)
                .clipShape(Capsule())
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: OuraTheme.Radius.large))
            .padding(.horizontal, 12)
            .padding(.bottom, 44)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Bottom overlay (non-cart mode)

    @ViewBuilder
    private var bottomOverlay: some View {
        switch scanState {
        case .scanning:
            scanHint
        case .resolving:
            resolvingCard
        case .resolved(let size):
            resolvedCard(size)
        case .error(let msg):
            errorCard(msg)
        }
    }

    private var scanHint: some View {
        HStack(spacing: 10) {
            Image(systemName: "qrcode.viewfinder")
                .font(.system(size: 18))
                .foregroundStyle(OuraTheme.Colors.accent)
            Text(mode == .sellOnly
                 ? "Scan QR untuk tambah ke keranjang"
                 : "Arahkan kamera ke QR code produk")
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(OuraTheme.Colors.textPrimary)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: OuraTheme.Radius.large))
        .padding(.bottom, 44)
    }

    private var resolvingCard: some View {
        HStack(spacing: 12) {
            ProgressView()
            Text("Mencari produk...")
                .font(.system(size: 14))
                .foregroundStyle(OuraTheme.Colors.textSecondary)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
        .background(OuraTheme.Colors.surfaceCard)
        .clipShape(RoundedRectangle(cornerRadius: OuraTheme.Radius.large))
        .overlay(RoundedRectangle(cornerRadius: OuraTheme.Radius.large)
            .stroke(OuraTheme.Colors.border, lineWidth: 1))
        .padding(.horizontal, 16)
        .padding(.bottom, 44)
    }

    private func resolvedCard(_ size: ProductSizeDetail) -> some View {
        VStack(spacing: 0) {
            Capsule()
                .fill(OuraTheme.Colors.border)
                .frame(width: 36, height: 4)
                .padding(.top, 10)

            VStack(alignment: .leading, spacing: 14) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(size.productName)
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(OuraTheme.Colors.textPrimary)
                    Text(size.displayLabel)
                        .font(.system(size: 14))
                        .foregroundStyle(OuraTheme.Colors.textSecondary)
                    HStack(spacing: 16) {
                        Label("Stok: \(size.currentStockQty) pcs", systemImage: "cube.box")
                        if let price = size.sellingPrice {
                            Label(price.rupiahFormatted, systemImage: "tag")
                        }
                    }
                    .font(.system(size: 12))
                    .foregroundStyle(OuraTheme.Colors.textTertiary)
                }

                if size.isArchived {
                    Text("Varian ini sudah dinonaktifkan.")
                        .font(.system(size: 13))
                        .foregroundStyle(OuraTheme.Colors.dangerText)
                        .padding(10)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(OuraTheme.Colors.dangerBg)
                        .clipShape(RoundedRectangle(cornerRadius: OuraTheme.Radius.medium))
                }

                if !size.isArchived {
                    VStack(spacing: 10) {
                        if mode != .stockInOnly {
                            Button {
                                resolvedSize = size
                                showSellSheet = true
                            } label: {
                                Text(size.currentStockQty > 0 ? "Catat Penjualan" : "Stok Habis")
                                    .font(.system(size: 15, weight: .semibold))
                                    .foregroundStyle(.white)
                                    .frame(maxWidth: .infinity)
                                    .frame(height: 48)
                                    .background(size.currentStockQty > 0
                                        ? OuraTheme.Colors.accentGradient
                                        : LinearGradient(colors: [OuraTheme.Colors.textDisabled],
                                                         startPoint: .leading, endPoint: .trailing))
                                    .clipShape(RoundedRectangle(cornerRadius: OuraTheme.Radius.large))
                            }
                            .buttonStyle(.plain)
                            .disabled(size.currentStockQty == 0)
                        }

                        if mode != .sellOnly {
                            Button {
                                resolvedSize = size
                                showStockSheet = true
                            } label: {
                                Text("Stok Masuk")
                                    .font(.system(size: 15, weight: .semibold))
                                    .foregroundStyle(OuraTheme.Colors.accent)
                                    .frame(maxWidth: .infinity)
                                    .frame(height: 48)
                                    .background(OuraTheme.Colors.surfaceSheet)
                                    .clipShape(RoundedRectangle(cornerRadius: OuraTheme.Radius.large))
                                    .overlay(RoundedRectangle(cornerRadius: OuraTheme.Radius.large)
                                        .stroke(OuraTheme.Colors.border, lineWidth: 1))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }

                Button { scanState = .scanning } label: {
                    Text("Scan Lagi")
                        .font(.system(size: 14))
                        .foregroundStyle(OuraTheme.Colors.textSecondary)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.plain)
            }
            .padding(16)
        }
        .background(OuraTheme.Colors.background)
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .shadow(color: .black.opacity(0.15), radius: 20, y: -4)
    }

    private func errorCard(_ msg: String) -> some View {
        VStack(spacing: 0) {
            Capsule()
                .fill(OuraTheme.Colors.border)
                .frame(width: 36, height: 4)
                .padding(.top, 10)

            VStack(spacing: 14) {
                HStack(spacing: 10) {
                    Image(systemName: "exclamationmark.triangle")
                        .foregroundStyle(OuraTheme.Colors.dangerText)
                    Text(msg)
                        .font(.system(size: 14))
                        .foregroundStyle(OuraTheme.Colors.textPrimary)
                    Spacer()
                }
                .padding(12)
                .background(OuraTheme.Colors.dangerBg)
                .clipShape(RoundedRectangle(cornerRadius: OuraTheme.Radius.medium))

                Button { scanState = .scanning } label: {
                    Text("Scan Lagi")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(OuraTheme.Colors.accent)
                        .frame(maxWidth: .infinity)
                        .frame(height: 48)
                        .background(OuraTheme.Colors.surfaceSheet)
                        .clipShape(RoundedRectangle(cornerRadius: OuraTheme.Radius.large))
                        .overlay(RoundedRectangle(cornerRadius: OuraTheme.Radius.large)
                            .stroke(OuraTheme.Colors.border, lineWidth: 1))
                }
                .buttonStyle(.plain)
            }
            .padding(16)
        }
        .background(OuraTheme.Colors.background)
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .shadow(color: .black.opacity(0.15), radius: 20, y: -4)
    }

    private var unsupportedView: some View {
        VStack(spacing: 16) {
            Image(systemName: "camera.slash")
                .font(.system(size: 48))
                .foregroundStyle(OuraTheme.Colors.textTertiary)
            Text("Kamera tidak tersedia")
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(OuraTheme.Colors.textPrimary)
            Text("Fitur scan membutuhkan iOS 16+ dan izin kamera.")
                .font(.system(size: 14))
                .foregroundStyle(OuraTheme.Colors.textSecondary)
                .multilineTextAlignment(.center)
        }
        .padding(32)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(OuraTheme.Colors.background)
    }

    // MARK: - Logic

    private func handleRawScan(_ raw: String) {
        guard raw.hasPrefix("oura:"),
              let uuid = UUID(uuidString: String(raw.dropFirst(5))),
              scanState == .scanning else { return }
        scanState = .resolving
        Task { await resolve(uuid) }
    }

    private func resolve(_ id: UUID) async {
        do {
            let size = try await api.getProductSizeById(id: id)
            if mode == .sellOnly {
                addToCart(size)
            } else {
                scanState = .resolved(size)
            }
        } catch {
            scanState = .error("Produk tidak ditemukan. QR mungkin sudah tidak aktif.")
        }
    }

    private func addToCart(_ size: ProductSizeDetail) {
        if let idx = cartItems.firstIndex(where: { $0.size.id == size.id }) {
            let newQty = cartItems[idx].qty + 1
            guard newQty <= size.currentStockQty else {
                cartToast = "Stok \(size.displayLabel) sudah penuh (\(size.currentStockQty) pcs)"
                scanState = .scanning
                scheduleToastDismiss()
                return
            }
            cartItems[idx].qty = newQty
            cartToast = "\(size.productName) · \(size.displayLabel) (\(newQty)×)"
        } else {
            cartItems.append(CartItem(size: size))
            cartToast = "\(size.productName) · \(size.displayLabel) ditambahkan"
        }
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        scanState = .scanning
        scheduleToastDismiss()
    }

    private func scheduleToastDismiss() {
        Task {
            try? await Task.sleep(nanoseconds: 1_800_000_000)
            withAnimation { cartToast = nil }
        }
    }
}

// MARK: - QR Cart Checkout Sheet

private struct QRCartCheckoutSheet: View {
    @EnvironmentObject private var api: APIService
    @Environment(\.dismiss) private var dismiss

    @Binding var cartItems: [CartItem]
    let onSuccess: () -> Void

    @AppStorage("qr_lastPaymentMethod") private var lastMethodRaw: String = PaymentMethod.cash.rawValue
    @State private var selectedMethod: PaymentMethod = .cash
    @State private var customerName: String = ""
    @State private var isSaving = false
    @State private var errorMsg: String?

    private var total: Double {
        cartItems.reduce(0) { $0 + $1.unitPrice * Double($1.qty) }
    }

    private var canCheckout: Bool {
        !cartItems.isEmpty && !isSaving
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    ForEach($cartItems) { $item in
                        cartItemRow(item: $item)
                    }
                    .onDelete { cartItems.remove(atOffsets: $0) }
                } header: {
                    OuraSectionHeader(title: "Produk (\(cartItems.reduce(0) { $0 + $1.qty }) item)")
                }
                .listSectionSeparator(.hidden)

                Section {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Metode Bayar")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(OuraTheme.Colors.textSecondary)
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                ForEach(PaymentMethod.allCases, id: \.self) { method in
                                    let selected = selectedMethod == method
                                    Button {
                                        selectedMethod = method
                                        lastMethodRaw = method.rawValue
                                    } label: {
                                        Text(method.displayName)
                                            .font(.system(size: 13, weight: .semibold))
                                            .foregroundStyle(selected ? .white : OuraTheme.Colors.textSecondary)
                                            .padding(.horizontal, 14)
                                            .padding(.vertical, 7)
                                            .background(selected ? OuraTheme.Colors.accent : OuraTheme.Colors.surfaceSheet)
                                            .clipShape(Capsule())
                                            .overlay(Capsule()
                                                .stroke(selected ? Color.clear : OuraTheme.Colors.border, lineWidth: 1))
                                    }
                                    .buttonStyle(.plain)
                                    .animation(.easeInOut(duration: 0.15), value: selectedMethod)
                                }
                            }
                            .padding(.horizontal, 1)
                        }
                    }
                    .listRowBackground(OuraTheme.Colors.surfaceCard)
                    .listRowInsets(EdgeInsets(top: 10, leading: 16, bottom: 10, trailing: 16))

                    TextField("Nama pembeli (opsional)", text: $customerName)
                        .font(.system(size: 14))
                        .foregroundStyle(OuraTheme.Colors.textPrimary)
                        .listRowBackground(OuraTheme.Colors.surfaceCard)
                        .listRowInsets(EdgeInsets(top: 12, leading: 16, bottom: 12, trailing: 16))
                } header: {
                    OuraSectionHeader(title: "Pembayaran")
                }
                .listSectionSeparator(.hidden)

                Section {
                    HStack {
                        Text("Total")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(OuraTheme.Colors.textPrimary)
                        Spacer()
                        Text(total.rupiahFormatted)
                            .font(.system(size: 17, weight: .bold))
                            .foregroundStyle(OuraTheme.Colors.accent)
                    }
                    .listRowBackground(OuraTheme.Colors.surfaceCard)
                    .listRowInsets(EdgeInsets(top: 14, leading: 16, bottom: 14, trailing: 16))
                }
                .listSectionSeparator(.hidden)

                if let err = errorMsg {
                    Section {
                        Text(err)
                            .font(.system(size: 13))
                            .foregroundStyle(OuraTheme.Colors.dangerText)
                            .listRowBackground(OuraTheme.Colors.dangerBg)
                            .listRowInsets(EdgeInsets(top: 10, leading: 16, bottom: 10, trailing: 16))
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .background(OuraTheme.Colors.background)
            .navigationTitle("Checkout")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Kembali") { dismiss() }
                        .foregroundStyle(OuraTheme.Colors.accent)
                }
            }
            .safeAreaInset(edge: .bottom) {
                VStack(spacing: 0) {
                    Divider().overlay(OuraTheme.Colors.separator)
                    Button {
                        Task { await checkout() }
                    } label: {
                        Group {
                            if isSaving {
                                ProgressView().tint(.white)
                            } else {
                                Text("Konfirmasi Pembayaran · \(total.rupiahFormatted)")
                                    .font(.system(size: 15, weight: .semibold))
                                    .foregroundStyle(.white)
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                        .background(canCheckout
                            ? OuraTheme.Colors.accentGradient
                            : LinearGradient(colors: [OuraTheme.Colors.border],
                                             startPoint: .leading, endPoint: .trailing))
                        .clipShape(RoundedRectangle(cornerRadius: OuraTheme.Radius.large))
                    }
                    .buttonStyle(.plain)
                    .disabled(!canCheckout)
                    .padding(16)
                }
                .background(OuraTheme.Colors.background)
            }
        }
        .onAppear {
            selectedMethod = PaymentMethod(rawValue: lastMethodRaw) ?? .cash
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }

    @ViewBuilder
    private func cartItemRow(item: Binding<CartItem>) -> some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                Text(item.wrappedValue.size.productName)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(OuraTheme.Colors.textPrimary)
                Text(item.wrappedValue.size.displayLabel)
                    .font(.system(size: 12))
                    .foregroundStyle(OuraTheme.Colors.textSecondary)
                Text(item.wrappedValue.unitPrice.rupiahFormatted)
                    .font(.system(size: 12))
                    .foregroundStyle(OuraTheme.Colors.textTertiary)
            }

            Spacer()

            // Qty stepper: trash when qty = 1 to remove on tap
            HStack(spacing: 4) {
                Button {
                    if item.wrappedValue.qty > 1 {
                        item.qty.wrappedValue -= 1
                    } else {
                        cartItems.removeAll { $0.id == item.wrappedValue.id }
                    }
                } label: {
                    Image(systemName: item.wrappedValue.qty > 1 ? "minus.circle" : "trash.circle")
                        .font(.system(size: 24))
                        .foregroundStyle(item.wrappedValue.qty > 1
                            ? OuraTheme.Colors.accent
                            : OuraTheme.Colors.dangerText)
                }
                .buttonStyle(.plain)

                Text("\(item.wrappedValue.qty)")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(OuraTheme.Colors.textPrimary)
                    .frame(minWidth: 30, alignment: .center)

                Button {
                    guard item.wrappedValue.qty < item.wrappedValue.size.currentStockQty else { return }
                    item.qty.wrappedValue += 1
                } label: {
                    Image(systemName: "plus.circle")
                        .font(.system(size: 24))
                        .foregroundStyle(item.wrappedValue.qty < item.wrappedValue.size.currentStockQty
                            ? OuraTheme.Colors.accent
                            : OuraTheme.Colors.border)
                }
                .buttonStyle(.plain)
                .disabled(item.wrappedValue.qty >= item.wrappedValue.size.currentStockQty)
            }
        }
        .listRowBackground(OuraTheme.Colors.surfaceCard)
        .listRowInsets(EdgeInsets(top: 12, leading: 16, bottom: 12, trailing: 16))
    }

    private func checkout() async {
        isSaving = true
        errorMsg = nil
        defer { isSaving = false }

        let reqItems = cartItems.map {
            CreateSalesOrderRequest.ItemInput(
                productSizeId: $0.size.id,
                qty: $0.qty,
                unitPrice: $0.unitPrice,
                discount: nil
            )
        }

        let req = CreateSalesOrderRequest(
            customerName: customerName.trimmingCharacters(in: .whitespaces).isEmpty ? nil : customerName,
            paymentMethod: selectedMethod.rawValue,
            marketplaceFeePct: selectedMethod == .marketplace ? 0.05 : nil,
            items: reqItems
        )

        do {
            let order = try await api.createSalesOrder(req)
            _ = try? await api.markSalesOrderPaid(id: order.id)
            cartItems.removeAll()
            dismiss()
            onSuccess()
        } catch let e as APIError {
            errorMsg = e.errorDescription
        } catch {
            errorMsg = error.localizedDescription
        }
    }
}

// MARK: - DataScanner wrapper

private struct DataScannerRepresentable: UIViewControllerRepresentable {
    let isActive: Bool
    let onScan: (String) -> Void

    func makeUIViewController(context: Context) -> DataScannerViewController {
        let scanner = DataScannerViewController(
            recognizedDataTypes: [.barcode(symbologies: [.qr])],
            qualityLevel: .balanced,
            recognizesMultipleItems: false,
            isHighFrameRateTrackingEnabled: false,
            isGuidanceEnabled: true,
            isHighlightingEnabled: true
        )
        scanner.delegate = context.coordinator
        return scanner
    }

    func updateUIViewController(_ uiViewController: DataScannerViewController, context: Context) {
        if isActive {
            try? uiViewController.startScanning()
        } else {
            uiViewController.stopScanning()
        }
    }

    func makeCoordinator() -> Coordinator { Coordinator(onScan: onScan) }

    class Coordinator: NSObject, DataScannerViewControllerDelegate {
        let onScan: (String) -> Void
        private var lastScanned: String?

        init(onScan: @escaping (String) -> Void) { self.onScan = onScan }

        func dataScanner(_ dataScanner: DataScannerViewController,
                         didAdd addedItems: [RecognizedItem],
                         allItems: [RecognizedItem]) {
            guard case .barcode(let barcode) = addedItems.first,
                  let raw = barcode.payloadStringValue,
                  raw != lastScanned else { return }
            lastScanned = raw
            onScan(raw)
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) { [weak self] in
                self?.lastScanned = nil
            }
        }
    }
}
