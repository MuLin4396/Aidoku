//
//  SourceListsView.swift
//  Aidoku
//
//  Created by Skitty on 6/5/25.
//

import SwiftUI
import UniformTypeIdentifiers

struct SourceListsView: View {
    @State private var sourceListsURLs: [URL] = []
    @State private var sourceLists: [URL: SourceList] = [:]
    @State private var missingSourceLists: Set<URL> = []
    @State private var showAddListFailAlert = false
    @State private var addListFailMessage = NSLocalizedString("SOURCE_LIST_ADD_FAIL_TEXT")
    @State private var importing = false
    @State private var pendingImportData: Data?

    private var activeSourceListURLs: [URL] {
        sourceListsURLs.filter {
            !missingSourceLists.contains($0)
        }
    }

    var body: some View {
        List {
            Section {
                ForEach(activeSourceListURLs, id: \.self) { url in
                    if let sourceList = sourceLists[url] {
                        listItem(name: sourceList.name, url: sourceList.url)
                    } else {
                        listItem(url: url, loading: true)
                    }
                }
                .onDelete(perform: delete)
            }

            if !missingSourceLists.isEmpty {
                Section {
                    ForEach(sourceListsURLs, id: \.self) { url in
                        if missingSourceLists.contains(url) {
                            listItem(url: url)
                        }
                    }
                } header: {
                    Text(NSLocalizedString("UNAVAILABLE_SOURCE_LISTS"))
                } footer: {
                    Text(NSLocalizedString("UNAVAILABLE_SOURCE_LISTS_TEXT"))
                }
            }
        }
        .navigationTitle(NSLocalizedString("SOURCE_LISTS"))
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Button {
                        showAlert()
                    } label: {
                        Label(NSLocalizedString("SOURCE_LIST_ADD"), systemImage: "link")
                    }
                    Button {
                        importing = true
                    } label: {
                        Label(NSLocalizedString("SOURCE_LIST_IMPORT"), systemImage: "square.and.arrow.down")
                    }
                } label: {
                    Image(systemName: "plus")
                }
            }
        }
        .sheet(isPresented: $importing) {
            DocumentPickerView(
                allowedContentTypes: [.json, .data],
                onDocumentsPicked: { urls in
                    importing = false
                    guard let url = urls.first else { return }
                    importSourceList(from: url)
                }
            )
            .ignoresSafeArea()
        }
        .alert(NSLocalizedString("SOURCE_LIST_ADD_FAIL"), isPresented: $showAddListFailAlert) {
            Button(NSLocalizedString("OK"), role: .cancel) {}
        } message: {
            Text(addListFailMessage)
        }
        .onReceive(NotificationCenter.default.publisher(for: .updateSourceLists)) { _ in
            Task {
                await loadSourceLists()
            }
        }
        .task {
            guard sourceLists.isEmpty else { return }
            await loadSourceLists()
        }
    }

    func loadSourceLists() async {
        sourceListsURLs = await SourceManager.shared.getSourceListURLs().sorted { $0.absoluteString < $1.absoluteString }

        if await SourceManager.shared.sourceListLoadFinished {
            missingSourceLists = await SourceManager.shared.getMissingSourceLists()
            sourceLists = await SourceManager.shared.getLoadedSourceLists()
        } else {
            missingSourceLists = []
            sourceLists = [:]

            let stream = await SourceManager.shared.streamSourceListsLoad()
            for await url in stream {
                let sourceList = await SourceManager.shared.getSourceList(url: url)
                withAnimation {
                    sourceLists[url] = sourceList
                }
            }

            let newMissingSourceLists = await SourceManager.shared.getMissingSourceLists()
            withAnimation {
                missingSourceLists = newMissingSourceLists
            }
        }
    }

    func listItem(name: String? = nil, url: URL, loading: Bool = false) -> some View {
        HStack {
            VStack(alignment: .leading) {
                if let name {
                    Text(name)
                }
                Text(url.absoluteString)
                    .lineLimit(1)
                    .font(.subheadline)
                    .foregroundStyle(name == nil ? .primary : .secondary)
            }
            if loading {
                ProgressView().progressViewStyle(.circular)
            }
        }
        .contextMenu {
            Button(role: .destructive) {
                sourceListsURLs.firstIndex(of: url).flatMap {
                    _ = sourceListsURLs.remove(at: $0)
                }
                sourceLists.removeValue(forKey: url)
                missingSourceLists.remove(url)
                Task {
                    await SourceManager.shared.removeSourceList(url: url)
                }
            } label: {
                Label(NSLocalizedString("REMOVE"), systemImage: "trash")
            }
            Button {
                UIPasteboard.general.string = url.absoluteString
            } label: {
                Label(NSLocalizedString("COPY_URL"), systemImage: "doc.on.doc")
            }
        }
    }

    func delete(at offsets: IndexSet) {
        let activeURLs = activeSourceListURLs
        let deleteURLs = offsets.map { activeURLs[$0] }
        Task {
            for url in deleteURLs {
                await SourceManager.shared.removeSourceList(url: url)
            }
        }
    }

    func importSourceList(from fileURL: URL) {
        let secured = fileURL.startAccessingSecurityScopedResource()
        defer {
            if secured {
                fileURL.stopAccessingSecurityScopedResource()
            }
        }
        guard let data = try? Data(contentsOf: fileURL) else {
            addListFailMessage = NSLocalizedString("SOURCE_LIST_IMPORT_FAIL_TEXT")
            showAddListFailAlert = true
            return
        }
        guard let parsed = SourceList.parse(data: data, url: SourceList.communityIndexURL) else {
            addListFailMessage = NSLocalizedString("SOURCE_LIST_IMPORT_FAIL_TEXT")
            showAddListFailAlert = true
            return
        }
        if SourceList.isCommunityList(parsed) {
            addLocalSourceList(data: data, url: SourceList.communityIndexURL)
            return
        }
        pendingImportData = data
        showAlert(forImportedList: true)
    }

    func addLocalSourceList(data: Data, url: URL) {
        Task {
            let result = await SourceManager.shared.addSourceListFromLocalData(data, url: url)
            if result.succeeded {
                await loadSourceLists()
            } else {
                addListFailMessage = result.failureMessage
                showAddListFailAlert = true
            }
        }
    }

    func addSourceList(url: String) {
        let url = url.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !url.isEmpty else { return }
        if let pendingImportData {
            self.pendingImportData = nil
            guard let listURL = URL(string: url) else {
                addListFailMessage = NSLocalizedString("SOURCE_LIST_ADD_FAIL_TEXT")
                showAddListFailAlert = true
                return
            }
            addLocalSourceList(data: pendingImportData, url: listURL)
            return
        }
        guard let url = URL(string: url) else {
            addListFailMessage = NSLocalizedString("SOURCE_LIST_ADD_FAIL_TEXT")
            showAddListFailAlert = true
            return
        }

        actor Done {
            var value: Bool = false
            func set() {
                value = true
            }
        }
        let done = Done()

        Task {
            // show loading indicator if it takes longer than 0.5s
            Task {
                try? await Task.sleep(nanoseconds: 500_000_000)
                let finished = await done.value
                if !finished {
                    await MainActor.run {
                        UIApplication.shared.appDelegate?.showLoadingIndicator()
                    }
                }
            }

            let result = await SourceManager.shared.addSourceListResult(url: url)
            await done.set()
            await UIApplication.shared.appDelegate?.hideLoadingIndicator()

            if result.succeeded {
                await loadSourceLists()
            } else {
                addListFailMessage = result.failureMessage
                showAddListFailAlert = true
            }
        }
    }

    func showAlert(forImportedList: Bool = false) {
        var alertTextField: UITextField?
        UIApplication.shared.appDelegate?.presentAlert(
            title: NSLocalizedString("SOURCE_LIST_ADD"),
            message: NSLocalizedString(forImportedList ? "SOURCE_LIST_IMPORT_URL_TEXT" : "SOURCE_LIST_ADD_TEXT"),
            actions: [
                UIAlertAction(title: NSLocalizedString("CANCEL"), style: .cancel) { _ in
                    pendingImportData = nil
                },
                UIAlertAction(title: NSLocalizedString("OK"), style: .default) { _ in
                    guard let text = alertTextField?.text, !text.isEmpty else { return }
                    addSourceList(url: text)
                }
            ],
            textFieldHandlers: [
                { textField in
                    textField.placeholder = NSLocalizedString("SOURCE_LIST_URL")
                    textField.keyboardType = .URL
                    textField.autocorrectionType = .no
                    textField.autocapitalizationType = .none
                    textField.returnKeyType = .done
                    alertTextField = textField
                }
            ]
        )
    }
}

#Preview {
    SourceListsView()
}
