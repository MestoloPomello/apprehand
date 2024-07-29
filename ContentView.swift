import SwiftUI

struct Menu_View: View {
    @State private var showLanguageMenu = false
    
    var body: some View {
        NavigationView {
            ZStack {
                // Immagine di sfondo
                Image("Sfondo home")
                    .resizable() // Rende l'immagine ridimensionabile
                    .scaledToFill() // Rende l'immagine adatta a riempire l'intera area
                    .ignoresSafeArea() // Fa sì che l'immagine riempia anche le aree sicure (come notch, bordi ecc.)
                
                // Pulsantiera
                VStack(spacing: 20) {
                    // Prima riga di pulsanti
                    HStack(spacing: 20) {
                        CustomButton_Impara(imageName: "book.fill", title: "Impara", gradientColors: [Color(hex: 0xd7dbfc), Color(hex: 0x8785f2)])
                        CustomButton_Allenati(imageName: "dumbbell.fill", title: "Allenati", gradientColors:[Color(hex: 0xbae4fc), Color(hex: 0x3fabd9)] )
                    }
                    // Seconda riga di pulsanti
                    CustomButton_Lingua(imageName: "globe", title: "Lingua", gradientColors: [Color(hex: 0xecd7fc), Color(hex: 0xc285f2)], showLanguageMenu: $showLanguageMenu)
                    .frame(width: 200, height: 100) // Dimensioni personalizzate per pulsante più grande
                }
                .padding(.top, 250)
                
                // Overlay per il menu di selezione della lingua
                if showLanguageMenu {
                    Color.black.opacity(0.5)
                        .ignoresSafeArea()
                        .onTapGesture {
                            withAnimation {
                                showLanguageMenu = false
                            }
                        }
                    
                    VStack {
                        Spacer()
                        LanguageMenu()
                            .padding()
                            .background(Color.white)
                            .cornerRadius(20)
                            .shadow(radius: 10)
                            .padding()
                        Spacer()
                    }
                    .transition(.move(edge: .bottom))
                    .zIndex(1)
                }
            }
        }
    }
}

struct CustomButton_Impara: View {
    var imageName: String
    var title: String
    var gradientColors: [Color]
    
    var body: some View {
        NavigationLink(destination: LevelSelectionView(viewContext: "impara")) {
            VStack {
                Image("Impara")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 100, height: 100)
                    .padding(.top, 20)
                Text(title)
                    .font(.system(size: 25))
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                    .padding(.bottom, 20)
                    .shadow(
                        color: Color.black.opacity(0.2),
                        radius: 4,
                        x: 0,
                        y: 4
                    )
            }
            .frame(width: 162, height: 250)
            .background(
                LinearGradient(gradient: Gradient(colors: gradientColors), startPoint: .top, endPoint: .bottom)
            )
            .cornerRadius(15)
            .shadow(color: Color(hex: 0x4c3fe4), radius: 0, x: 0, y: 5)
        }
        .buttonStyle(.plain)
    }
}

struct LanguageMenu: View {
    var body: some View {
        VStack(spacing: 20) {
            LanguageMenuButton(flagImage: "IT", language: "Italiano")
            LanguageMenuButton(flagImage: "ENG", language: "Inglese")
            LanguageMenuButton(flagImage: "FR", language: "Francese")
            LanguageMenuButton(flagImage: "SP", language: "Spagnolo")
        }
        .padding(20)
    }
}

struct LanguageMenuButton: View {
    var flagImage: String
    var language: String
    
    var body: some View {
        HStack(spacing: 30) {
            Image(flagImage)
                .resizable()
                .scaledToFit()
                .frame(width: 65, height: 65)
            Text(language)
                .font(.system(size: 25))
                .fontWeight(.bold)
                .shadow(
                    color: Color.black.opacity(0.2),
                    radius: 4,
                    x: 0,
                    y: 4
                )
            Spacer()
        }
        .padding()
        .background(Color.white)
        .cornerRadius(10)
        .shadow(radius: 5)
    }
}

struct CustomButton_Allenati: View {
    var imageName: String
    var title: String
    var gradientColors: [Color]
    
    var body: some View {
        NavigationLink(destination: LevelSelectionView(viewContext: "allenati")) {
            VStack {
                Image("Allenati")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 100, height: 100)
                    .padding(.top, 20)
                Text(title)
                    .font(.system(size: 25))
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                    .padding(.bottom, 20)
                    .shadow(
                        color: Color.black.opacity(0.2),
                        radius: 4,
                        x: 0,
                        y: 4
                    )
            }
            .frame(width: 162, height: 250)
            .background(
                LinearGradient(gradient: Gradient(colors: gradientColors), startPoint: .top, endPoint: .bottom)
            )
            
            .cornerRadius(15)
            .shadow(color: Color(hex: 0x277099), radius: 0, x: 0, y: 5)
            
        }
        .buttonStyle(.plain)
    }
}

struct CustomButton_Lingua: View {
    var imageName: String
    var title: String
    var gradientColors: [Color]
    @Binding var showLanguageMenu: Bool
    
    var body: some View {
        Button(action: {
            withAnimation {
                showLanguageMenu.toggle()
            }
        }) {
            HStack(alignment: .center, spacing: 65) {
                Image("Lingua")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 65, height: 65)
                //.padding(.horizontal, -10)
                Text(title)
                    .font(.system(size: 25))
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                    .shadow(
                        color: Color.black.opacity(0.2),
                        radius: 4,
                        x: 0,
                        y: 4
                    )
            }
            .frame(width: 350, height: 100)
            .background(
                LinearGradient(gradient: Gradient(colors: gradientColors), startPoint: .top, endPoint: .bottom)
            )
            .cornerRadius(20)
            .shadow(color: Color(hex: 0x3f0071, opacity: 0.75), radius: 0, x: 0, y: 5)
        }
        .buttonStyle(.plain)
    }
}

struct Menu_ViewPreviews: PreviewProvider {
    static var previews: some View {
        Menu_View()
    }
}