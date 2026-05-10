//
//  ContentView.swift
//  metalism
//
//  Created by Usman Nazir on 04/05/2026.
//

import SwiftUI

struct ContentView: View {
    var body: some View {
        NavigationStack {
            List {
                Section {
                    NavigationLink {
                        Glass_05_2026()
                    } label: {
                        Label("Glass", systemImage: "square.on.square")
                    }

                    NavigationLink {
                        ParticlesDemo()
                    } label: {
                        Label("Floating Particles", systemImage: "circle.grid.3x3.fill")
                    }

                    NavigationLink {
                        BeesDemo()
                    } label: {
                        Label("Bees", systemImage: "circle.hexagonpath.fill")
                    }

                    NavigationLink {
                        RainDemo()
                    } label: {
                        Label("Rain", systemImage: "cloud.rain.fill")
                    }

                    NavigationLink {
                        RepelDemo()
                    } label: {
                        Label("Repel Grid", systemImage: "dot.radiowaves.left.and.right")
                    }

                    NavigationLink {
                        DustShapeDemo()
                    } label: {
                        Label("Dust Shape", systemImage: "star.fill")
                    }

                    NavigationLink {
                        LetterParticlesDemo()
                    } label: {
                        Label("Letter Particles", systemImage: "textformat.characters")
                    }

                    NavigationLink {
                        ConfettiDemo()
                    } label: {
                        Label("Confetti", systemImage: "party.popper.fill")
                    }

                    NavigationLink {
                        LightningDemo()
                    } label: {
                        Label("Lightning", systemImage: "bolt.fill")
                    }

                    NavigationLink {
                        GodRaysDemo()
                    } label: {
                        Label("God Rays", systemImage: "sun.horizon.fill")
                    }

                    NavigationLink {
                        WarpTouchDemo()
                    } label: {
                        Label("Warp Touch", systemImage: "hand.draw.fill")
                    }

                    NavigationLink {
                        TapGlowDemo()
                    } label: {
                        Label("Tap Glow", systemImage: "circle.circle.fill")
                    }

                    NavigationLink {
                        EdgeGlowDemo()
                    } label: {
                        Label("Edge Glow", systemImage: "circle.dashed")
                    }

                    NavigationLink {
                        DonutGlowDemo()
                    } label: {
                        Label("Donut Glow", systemImage: "circle.dashed.inset.filled")
                    }

                    NavigationLink {
                        SwitchGlowDemo()
                    } label: {
                        Label("Switch Glow", systemImage: "switch.2")
                    }

                    NavigationLink {
                        WaterWaveDemo()
                    } label: {
                        Label("Water Wave", systemImage: "water.waves")
                    }

                    NavigationLink {
                        Wave3DDemo()
                    } label: {
                        Label("Wave 3D", systemImage: "view.3d")
                    }

                    NavigationLink {
                        WavePerspectiveDemo()
                    } label: {
                        Label("Wave Perspective", systemImage: "perspective")
                    }

                    NavigationLink {
                        WaveStretchDemo()
                    } label: {
                        Label("Wave Stretch", systemImage: "arrow.up.and.down.square")
                    }

                    NavigationLink {
                        RainbowListDemo()
                    } label: {
                        Label("Rainbow List", systemImage: "list.bullet.rectangle.fill")
                    }

                    NavigationLink {
                        RainbowListBlurDemo()
                    } label: {
                        Label("Rainbow List Blur", systemImage: "list.bullet.rectangle")
                    }

                    NavigationLink {
                        ShatteredGlassDemo()
                    } label: {
                        Label("Shattered Glass", systemImage: "mosaic.fill")
                    }

                    NavigationLink {
                        RadialShatterDemo()
                    } label: {
                        Label("Radial Shatter", systemImage: "circle.and.line.horizontal.fill")
                    }

                    NavigationLink {
                        WaterDropletDemo()
                    } label: {
                        Label("Water Droplets", systemImage: "drop.fill")
                    }

                    NavigationLink {
                        ListBlobDemo()
                    } label: {
                        Label("List Blob", systemImage: "circle.inset.filled")
                    }

                    NavigationLink {
                        ListBlobTextDemo()
                    } label: {
                        Label("List Blob Text", systemImage: "character.cursor.ibeam")
                    }

                    NavigationLink {
                        ListBlobTanDemo()
                    } label: {
                        Label("List Blob Tan", systemImage: "circle.dotted.and.circle")
                    }

                    NavigationLink {
                        ListBlobSquareDemo()
                    } label: {
                        Label("List Blob Square", systemImage: "square.inset.filled")
                    }

                    NavigationLink {
                        BottomWaveDemo()
                    } label: {
                        Label("Bottom Wave", systemImage: "waveform.path")
                    }

                    NavigationLink {
                        BottomWaveVerticalDemo()
                    } label: {
                        Label("Bottom Wave Vertical", systemImage: "waveform.path.ecg")
                    }

                    NavigationLink {
                        LiquidBlockDemo()
                    } label: {
                        Label("Liquid Block", systemImage: "rectangle.inset.filled")
                    }

                    NavigationLink {
                        LiquidBlockModifierDemo()
                    } label: {
                        Label("Liquid Block Modifier", systemImage: "rectangle.3.group.fill")
                    }
                }
            }
            .navigationTitle("Metalism")
        }
    }
}

#Preview {
    ContentView()
}
