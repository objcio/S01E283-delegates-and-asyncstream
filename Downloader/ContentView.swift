//
//  ContentView.swift
//  Downloader
//
//  Created by Chris Eidhof on 15.11.21.
//

import SwiftUI

let urls = [
    URL(string: "https://www.objc.io/index.html")!,
    URL(string: "http://ftp.acc.umu.se/mirror/wikimedia.org/dumps/enwiki/20211101/enwiki-20211101-abstract.xml.gz")!
]

struct DownloadView: View {
    @ObservedObject var model: DownloadModel
    
    var body: some View {
        VStack {
            Text("\(model.url)")
            if let p = model.progress, p.bytesExpected > 0 {
                ProgressView("Progress", value: Double(p.bytesWritten), total: Double(p.bytesExpected))
                    .progressViewStyle(.linear)
            }
            switch model.state {
            case .notStarted:
                Button("Start") {
                    Task { [model] in
                        await model.start()
                    }
                }
            case .started:
                HStack {
                    if model.progress == nil {
                        ProgressView()
                            .progressViewStyle(.linear)
                    }
                    Button("Cancel") {
                        Task { [model] in
                            await model.pause()
                        }
                    }
                }
            case .paused(resumeData: _):
                Text("Paused...")
                Button("Resume") {
                    Task { [model] in
                        await model.start()
                    }
                }
            case let .done(url):
                Text("Done: \(url)")
            }
        }
    }
}

struct ContentView: View {
    var body: some View {
        VStack {
            ForEach(urls, id: \.self) { url in
                DownloadView(model: DownloadModel(url))
            }
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
