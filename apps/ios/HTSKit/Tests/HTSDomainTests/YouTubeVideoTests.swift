import Foundation
import HTSDomain
import Testing

@Suite struct YouTubeVideoTests {
    func video(_ link: String) -> YouTubeVideo? { YouTubeVideo(url: URL(string: link)!) }

    @Test func readsTheLinkShapesFromTheCoachPDFs() {
        let short = video("https://youtube.com/shorts/193hwFtuKJo?si=Fm3KRYj5BAHK48JL")
        #expect(short?.id == "193hwFtuKJo")
        #expect(short?.isShort == true)
        #expect(video("https://www.youtube.com/shorts/-lMYNWGiUW8")?.id == "-lMYNWGiUW8")

        let watch = video("https://www.youtube.com/watch?v=72UUJVBuT7o&t=4s")
        #expect(watch?.id == "72UUJVBuT7o")
        #expect(watch?.start == 4)
        #expect(watch?.isShort == false)
        #expect(video("https://youtu.be/ABi1Z1Gc9Tw?si=V0xgzidESI13nay9")?.id == "ABi1Z1Gc9Tw")
    }

    @Test func otherLinksAreNotPlayedInline() {
        #expect(video("https://vimeo.com/123") == nil)
        #expect(video("https://www.youtube.com/@canal") == nil)
        #expect(video("https://notyoutube.com/shorts/abc") == nil)
    }

    @Test func embedsInlineWithAutoplayAndTheStart() {
        let url = video("https://www.youtube.com/watch?v=72UUJVBuT7o&t=4s")!.embedURL(origin: "https://hts.local")
        #expect(
            url.absoluteString
                == "https://www.youtube.com/embed/72UUJVBuT7o?playsinline=1&autoplay=1&rel=0&origin=https://hts.local&start=4"
        )
    }
}
