import HTSDomain
import Testing

@Suite struct InitialsTests {
    @Test func firstAndLastNameAtMostTwoLetters() {
        #expect(Initials.of("Leonardo Theodoro") == "LT")
        #expect(Initials.of("Leonardo") == "L")
        #expect(Initials.of("leonardo de souza theodoro") == "LT")
        #expect(Initials.of("  Ângelo   Érico ") == "ÂÉ")
        #expect(Initials.of("   ") == "")
    }
}
