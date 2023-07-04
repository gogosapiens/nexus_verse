import Foundation

public enum FriendlyApp: String, CaseIterable {
    
    case netflix, youTube, appleTV, spotify, primeVideo, disneyPlus, hboMax, googlePlay, browser, ted, hboGo, vevo, vimeo
    
    public var ids: [String] {
        switch self {
        case .netflix:      return ["11101200001", "netflix", "com.netflix.mediaclient", "12"]
        case .youTube:      return ["111299001912", "youtube.leanback.v4", "com.google.android.youtube.tv", "837"]
        case .appleTV:      return ["com.apple.appletv", "com.apple.atve.sony.appletv", "551012"]
        case .spotify:      return ["3201606009684", "spotify-beehive", "com.spotify.tv.android", "22297"]
        case .primeVideo:   return ["3201512006785", "amazon", "com.amazon.amazonvideo.livingroom", "13"]
        case .disneyPlus:   return ["3201901017640", "com.disney.disneyplus-prod", "com.disney.disneyplus", "291097"]
        case .hboMax:       return ["3201601007230", "com.hbo.hbomax", "com.hbo.hbonow"]
        case .googlePlay:   return ["3201601007250", "com.google.android.videos"]
        case .browser:      return ["org.tizen.browser", "com.webos.app.browser"]
        case .ted:          return ["111299001922", "com.ted.android.tv"]
        case .hboGo:        return ["3201706012478"]
        case .vevo:         return ["3201601007390", "com.vevo.tv", "644183"]
        case .vimeo:        return ["11101000410", "com.vimeo.android.videoapp"]
        }
    }
}
