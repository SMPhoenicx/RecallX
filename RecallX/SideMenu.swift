//
//  SideMenu.swift
//  RecallX
//
//  Created by Suman Muppavarapu on 3/15/25.
//

import SwiftUI

struct SideMenu: View{
    @Binding var isShowing: Bool
    @State var selected: Page = .home
    var body: some View{
        ZStack{
            if isShowing{
                Rectangle()
                    .opacity(0.3)
                    .ignoresSafeArea()
                    .onTapGesture {
                        isShowing.toggle()
                    }
                HStack{
                    VStack(alignment: .leading){
                        HStack{
                           Text("Menu")
                                .font(.largeTitle)
                        }
                        .padding()
                        ForEach(Page.allCases, id: \.self){row in
                            Button(action:{
                                selected = row
                            }){
                                RowView(title: row.title, isSelected: row == selected, image: row.icon)
                            }
                        }
                        
                        Spacer()
                    }
                    .frame(maxWidth: 270, alignment: .leading)
                    
                    .background(.white)
                    Spacer()
                }
                
            }
        }
        .transition(.move(edge: .leading))
        .animation(.easeInOut, value: isShowing)
    }
    
    func RowView(title: String, isSelected: Bool, image: String) -> some View{
        
        HStack{
            Image(systemName: image)
                .padding(.leading)
             Text(title)
            Spacer()
        }
        .frame(height: 44)
        .background{
            if isSelected{
                RoundedRectangle(cornerRadius: 10)
                    .stroke(.black, lineWidth: 3)
            }
        }
        .padding(.horizontal)
        
    }
}

enum Page: Int, CaseIterable{
    case home
    case saved
    
    var title: String{
        switch self {
        case .home:
            return "Home"
        case .saved:
            return "Saved"
        }
    }
    var icon: String{
        switch self {
        case .home:
            return "house.fill"
        case .saved:
            return "bookmark.fill"
        }
    }
    
}
#Preview{
    SideMenu(isShowing: .constant(true))
}
