// TrayOrderTests.swift
// Checks the tray's saved order, where new items appear, hiding behind the chevron and moving by drag.
// Exists so a change to TrayOrder that reshuffles a user's tray or loses a hidden item fails a test.
// Defines: TrayOrderTests
// Notes: docs/notes/app/Tests/OpenTaskbarTests/TrayOrderTests.swift.md
import Testing
@testable import OpenTaskbar

struct TrayOrderTests {
    private func settings() -> BarSettings {
        var value = BarSettings()
        for id in TrayOrder.systemIDs { value.show[id] = true }
        return value.clamped()
    }

    @Test func freshTrayPutsStatusItemsFirstThenSystemItems() {
        let split = TrayOrder.split(settings(), apps: ["Claude", "Paste"], batteryPresent: true)
        #expect(split.shown == ["status:Claude", "status:Paste"] + TrayOrder.systemIDs)
        #expect(split.hidden.isEmpty)
    }

    @Test func batteryIsLeftOutWithoutABattery() {
        let split = TrayOrder.split(settings(), apps: [], batteryPresent: false)
        #expect(!split.shown.contains("battery"))
    }

    @Test func savedOrderWinsAndNewItemsFollowTheirDefaultNeighbor() {
        var value = settings()
        value.trayOrder = ["wifi", "volume", "status:Claude"]
        let split = TrayOrder.split(value, apps: ["Claude", "Paste"], batteryPresent: true)
        // Paste follows Claude, its neighbor in the default order; the saved three keep their order.
        let saved = split.shown.filter { ["wifi", "volume", "status:Claude"].contains($0) }
        #expect(saved == ["wifi", "volume", "status:Claude"])
        #expect(split.shown.firstIndex(of: "status:Paste") == (split.shown.firstIndex(of: "status:Claude") ?? -2) + 1)
    }

    @Test func hidingMovesAnItemBehindTheChevron() {
        let value = TrayOrder.hidden(settings(), id: "status:Claude", true)
        let hiddenSystem = TrayOrder.hidden(value, id: "volume", true)
        let split = TrayOrder.split(hiddenSystem, apps: ["Claude"], batteryPresent: true)
        #expect(split.hidden == ["status:Claude", "volume"])
        #expect(hiddenSystem.hiddenStatus["Claude"] == true)
        #expect(hiddenSystem.hiddenTray["volume"] == true)
    }

    @Test func movingPlacesTheItemAndShowsIt() {
        let hidden = TrayOrder.hidden(settings(), id: "wifi", true)
        let moved = TrayOrder.moved(hidden, id: "wifi", toShownIndex: 0, apps: ["Claude"], batteryPresent: true)
        let split = TrayOrder.split(moved, apps: ["Claude"], batteryPresent: true)
        #expect(split.shown.first == "wifi")
        #expect(split.hidden.isEmpty)
        #expect(!TrayOrder.isHidden("wifi", moved))
    }

    @Test func zoneKindsRoundTripThroughTrayIdentifiers() {
        for id in TrayOrder.systemIDs + ["status:Claude"] {
            #expect(BarZoneKind.tray(id)?.trayID == id)
        }
    }
}
