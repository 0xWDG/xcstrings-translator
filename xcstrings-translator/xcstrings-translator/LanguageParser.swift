//
//  LanguageParser.swift
//  xcstrings-translator
//
//  Created by Wesley de Groot on 31/01/2025.
//

import Foundation

struct LanguageItem: Codable {
    var base: String

    // ISO Languages
    // swiftlint:disable identifier_name
    var nl: String
    var en: String
    var fr: String
    var de: String
    // swiftlint:enable identifier_name
}

class LanguageParser: ObservableObject {
    // swiftlint:disable:previous type_body_length
    @Published var languageDictionary: [String: Any] = [:]
    @Published var stringsToTranslate: [String] = []
    @Published var shouldTranslate: [Bool] = []
    @Published var sourceLanguage: String = "en"
    @Published var fileURL: URL?
    var isTesting = true

    var json = #"""
{
  "sourceLanguage" : "en",
  "strings" : {
    " " : {
      "localizations" : {
        "nl" : {
          "stringUnit" : {
            "state" : "translated",
            "value" : " "
          }
        }
      }
    },
    "!\n" : {
      "shouldTranslate" : false
    },
    "%@" : {
      "localizations" : {
        "nl" : {
          "stringUnit" : {
            "state" : "translated",
            "value" : "%@"
          }
        }
      },
      "shouldTranslate" : false
    },
    "%@ sent you a message!" : {
      "extractionState" : "manual",
      "localizations" : {
        "nl" : {
          "stringUnit" : {
            "state" : "translated",
            "value" : "%@ heeft je een bericht gestuurd!"
          }
        }
      }
    },
    "%@, %@" : {
      "localizations" : {
        "en" : {
          "stringUnit" : {
            "state" : "new",
            "value" : "%1$@, %2$@"
          }
        }
      },
      "shouldTranslate" : false
    },
    "%@/10" : {

    },
    "0km" : {
      "shouldTranslate" : false
    },
    "500km" : {
      "shouldTranslate" : false
    },
    "About me" : {
      "extractionState" : "manual",
      "localizations" : {
        "nl" : {
          "stringUnit" : {
            "state" : "translated",
            "value" : "Over mij"
          }
        }
      }
    },
    "Add or make a picture." : {
      "localizations" : {
        "nl" : {
          "stringUnit" : {
            "state" : "translated",
            "value" : "Voeg een foto toe of maak een foto."
          }
        }
      }
    },
    "Add Photos" : {
      "localizations" : {
        "nl" : {
          "stringUnit" : {
            "state" : "translated",
            "value" : "Foto's toevoegen"
          }
        }
      }
    },
    "Age" : {
      "extractionState" : "manual",
      "localizations" : {
        "nl" : {
          "stringUnit" : {
            "state" : "translated",
            "value" : "Leeftijd"
          }
        }
      }
    },
    "Age %@" : {
      "localizations" : {
        "nl" : {
          "stringUnit" : {
            "state" : "translated",
            "value" : "Leeftijd %@"
          }
        }
      }
    },
    "Allow notifications" : {

    },
    "Automatic" : {
      "comment" : "Automatic",
      "extractionState" : "manual",
      "localizations" : {
        "nl" : {
          "stringUnit" : {
            "state" : "translated",
            "value" : "Automatisch"
          }
        }
      }
    },
    "Automatic (%@)" : {
      "comment" : "Automatic (%@)",
      "extractionState" : "manual",
      "localizations" : {
        "nl" : {
          "stringUnit" : {
            "state" : "translated",
            "value" : "Automatisch (%@)"
          }
        }
      }
    },
    "Be true to yourself" : {

    },
    "Biography" : {
      "extractionState" : "manual",
      "localizations" : {
        "nl" : {
          "stringUnit" : {
            "state" : "translated",
            "value" : "Biografie"
          }
        }
      }
    },
    "Chat with %@" : {
      "extractionState" : "manual",
      "localizations" : {
        "nl" : {
          "stringUnit" : {
            "state" : "translated",
            "value" : "Chat met %@"
          }
        }
      }
    },
    "City" : {
      "comment" : "City",
      "localizations" : {
        "nl" : {
          "stringUnit" : {
            "state" : "translated",
            "value" : "Stad"
          }
        }
      }
    },
    "Connections queue" : {
      "extractionState" : "manual",
      "localizations" : {
        "nl" : {
          "stringUnit" : {
            "state" : "translated",
            "value" : "Connectie wachtrij"
          }
        }
      }
    },
    "Continue" : {

    },
    "Dinner preferences" : {

    },
    "Dinner Preferences" : {
      "extractionState" : "manual",
      "localizations" : {
        "nl" : {
          "stringUnit" : {
            "state" : "translated",
            "value" : "Dinner voorkeuren"
          }
        }
      }
    },
    "DinnerConnect" : {
      "localizations" : {
        "nl" : {
          "stringUnit" : {
            "state" : "translated",
            "value" : "DinnerConnect"
          }
        }
      },
      "shouldTranslate" : false
    },
    "Dislike" : {
      "localizations" : {
        "nl" : {
          "stringUnit" : {
            "state" : "translated",
            "value" : "Vind ik niet leuk"
          }
        }
      }
    },
    "Distance" : {
      "extractionState" : "manual",
      "localizations" : {
        "nl" : {
          "stringUnit" : {
            "state" : "translated",
            "value" : "Afstand"
          }
        }
      }
    },
    "Don't hesitate to report bad behavior." : {

    },
    "Enable location" : {

    },
    "Ensure your photos, age, and bio accurately reflect who you are." : {

    },
    "ERROR" : {
      "shouldTranslate" : false
    },
    "Experiment" : {

    },
    "Failed to report" : {
      "localizations" : {
        "nl" : {
          "stringUnit" : {
            "state" : "translated",
            "value" : "Rapporteren mislukt"
          }
        }
      }
    },
    "Failed to unmatch" : {
      "localizations" : {
        "nl" : {
          "stringUnit" : {
            "state" : "translated",
            "value" : "Unmatched mislukt"
          }
        }
      }
    },
    "Get notified when there are new DinnerConnections and messages" : {

    },
    "HEAVY" : {
      "shouldTranslate" : false
    },
    "Hello %@" : {

    },
    "Hey " : {

    },
    "How do you identify?" : {

    },
    "I would like to have dinner with" : {
      "extractionState" : "manual",
      "localizations" : {
        "nl" : {
          "stringUnit" : {
            "state" : "translated",
            "value" : "Ik wil graag dineren met"
          }
        }
      }
    },
    "I'm a button" : {
      "localizations" : {
        "nl" : {
          "stringUnit" : {
            "state" : "translated",
            "value" : "Ik ben een knop 1"
          }
        }
      }
    },
    "I'm a button 2" : {
      "localizations" : {
        "nl" : {
          "stringUnit" : {
            "state" : "translated",
            "value" : "Ik ben een knop 2"
          }
        }
      }
    },
    "Interest" : {

    },
    "Interests" : {
      "extractionState" : "manual",
      "localizations" : {
        "nl" : {
          "stringUnit" : {
            "state" : "translated",
            "value" : "Interesses"
          }
        }
      }
    },
    "Keep safe" : {

    },
    "KM" : {
      "localizations" : {
        "nl" : {
          "stringUnit" : {
            "state" : "translated",
            "value" : "KM"
          }
        }
      }
    },
    "Let others know what you love to eat." : {

    },
    "Let the other know and restaurant know in advance that you'll will splitting the bill." : {

    },
    "LIGHT" : {
      "shouldTranslate" : false
    },
    "Like" : {
      "localizations" : {
        "nl" : {
          "stringUnit" : {
            "state" : "translated",
            "value" : "Vind ik leuk"
          }
        }
      }
    },
    "Likes" : {
      "localizations" : {
        "nl" : {
          "stringUnit" : {
            "state" : "translated",
            "value" : "Vind ik leuks"
          }
        }
      }
    },
    "Loading..." : {
      "localizations" : {
        "nl" : {
          "stringUnit" : {
            "state" : "translated",
            "value" : "Laden…"
          }
        }
      }
    },
    "Login (fast)" : {
      "localizations" : {
        "en" : {
          "stringUnit" : {
            "state" : "translated",
            "value" : "Login (fast) 🚀"
          }
        },
        "nl" : {
          "stringUnit" : {
            "state" : "translated",
            "value" : "Snel inloggen 🚀"
          }
        }
      }
    },
    "Logout" : {
      "localizations" : {
        "nl" : {
          "stringUnit" : {
            "state" : "translated",
            "value" : "Uitloggen"
          }
        }
      }
    },
    "MEDIUM" : {
      "shouldTranslate" : false
    },
    "Men" : {
      "localizations" : {
        "nl" : {
          "stringUnit" : {
            "state" : "translated",
            "value" : "Mannen"
          }
        }
      }
    },
    "Messages" : {
      "localizations" : {
        "nl" : {
          "stringUnit" : {
            "state" : "translated",
            "value" : "Berichten"
          }
        }
      }
    },
    "My birthday" : {

    },
    "No one is blocked." : {
      "localizations" : {
        "nl" : {
          "stringUnit" : {
            "state" : "translated",
            "value" : "Niemand is geblokkeerd"
          }
        }
      }
    },
    "No worries, you can change this later." : {

    },
    "Non-binary" : {
      "localizations" : {
        "nl" : {
          "stringUnit" : {
            "state" : "translated",
            "value" : "Non-binair"
          }
        }
      }
    },
    "Notifications" : {
      "extractionState" : "manual",
      "localizations" : {
        "nl" : {
          "stringUnit" : {
            "state" : "translated",
            "value" : "Notificaties"
          }
        }
      }
    },
    "Onboarding" : {

    },
    "Photos" : {
      "extractionState" : "manual",
      "localizations" : {
        "nl" : {
          "stringUnit" : {
            "state" : "translated",
            "value" : "Fotos"
          }
        }
      }
    },
    "Please wait for a brief moment while we set up your profile." : {

    },
    "Privacy Settings" : {
      "localizations" : {
        "nl" : {
          "stringUnit" : {
            "state" : "translated",
            "value" : "Privacy instellingen"
          }
        }
      }
    },
    "Profile Settings" : {
      "localizations" : {
        "nl" : {
          "stringUnit" : {
            "state" : "translated",
            "value" : "Profiel instellingen"
          }
        }
      }
    },
    "RangedSliderView" : {
      "localizations" : {
        "nl" : {
          "stringUnit" : {
            "state" : "translated",
            "value" : "RangedSliderView"
          }
        }
      }
    },
    "Searching for %@" : {
      "localizations" : {
        "nl" : {
          "stringUnit" : {
            "state" : "translated",
            "value" : "Zoeken naar %@"
          }
        }
      }
    },
    "Searching for...\nThe cutest people around you" : {
      "localizations" : {
        "nl" : {
          "stringUnit" : {
            "state" : "translated",
            "value" : "Zoeken naar...\nDe leukste mensen in de buurt"
          }
        }
      }
    },
    "Selected %@!" : {
      "localizations" : {
        "nl" : {
          "stringUnit" : {
            "state" : "translated",
            "value" : "%@ geselecteerd"
          }
        }
      }
    },
    "Send" : {
      "localizations" : {
        "nl" : {
          "stringUnit" : {
            "state" : "translated",
            "value" : "Verstuur"
          }
        }
      }
    },
    "Setting up profile...\n" : {

    },
    "Settings" : {
      "localizations" : {
        "nl" : {
          "stringUnit" : {
            "state" : "translated",
            "value" : "Instellingen"
          }
        }
      }
    },
    "Share what you love to talk about at dinner." : {

    },
    "SUCCESS" : {
      "shouldTranslate" : false
    },
    "Swipe to explore." : {
      "localizations" : {
        "nl" : {
          "stringUnit" : {
            "state" : "translated",
            "value" : "Swipe om te ondekken"
          }
        }
      }
    },
    "Take charge" : {

    },
    "Take it easy" : {

    },
    "Tell more about yourself." : {

    },
    "This can't be changed later" : {

    },
    "Type yor message here" : {
      "extractionState" : "manual",
      "localizations" : {
        "nl" : {
          "stringUnit" : {
            "state" : "translated",
            "value" : "Typ je bericht hier"
          }
        }
      }
    },
    "Unblock" : {
      "localizations" : {
        "nl" : {
          "stringUnit" : {
            "state" : "translated",
            "value" : "Deblokkeer"
          }
        }
      }
    },
    "Unmatch" : {
      "localizations" : {
        "nl" : {
          "stringUnit" : {
            "state" : "translated",
            "value" : "Unmatch"
          }
        }
      }
    },
    "Unmatch & Report" : {
      "localizations" : {
        "nl" : {
          "stringUnit" : {
            "state" : "translated",
            "value" : "Unmatch & Rapporteren"
          }
        }
      }
    },
    "Version %@" : {
      "localizations" : {
        "nl" : {
          "stringUnit" : {
            "state" : "translated",
            "value" : "Versie %@"
          }
        }
      }
    },
    "View debug logs" : {
      "localizations" : {
        "nl" : {
          "stringUnit" : {
            "state" : "translated",
            "value" : "Zie debug logs"
          }
        }
      }
    },
    "WARNING" : {
      "shouldTranslate" : false
    },
    "We can't find anyone nearby...\n\nPlease try again later" : {

    },
    "We embrace everyone." : {

    },
    "We use your location to show you potential DinnerConnections in your area" : {

    },
    "we use your location to show you potentioal DonnerConnections in your area." : {

    },
    "Welcome to DinnerConnect" : {

    },
    "Who are you interested in having dinner with?" : {
      "localizations" : {
        "nl" : {
          "stringUnit" : {
            "state" : "translated",
            "value" : "Met wie ben je geïnteresseerd om te eten?"
          }
        }
      }
    },
    "With DinnerConnect you can find the best dinner connections in your neighborhood" : {
      "localizations" : {
        "nl" : {
          "stringUnit" : {
            "state" : "translated",
            "value" : "Met DinnerConnect vind je de beste diner connecties bij jou in de buurt"
          }
        }
      }
    },
    "Women" : {
      "localizations" : {
        "nl" : {
          "stringUnit" : {
            "state" : "translated",
            "value" : "Vrouwen"
          }
        }
      }
    },
    "You won't be able to change it later." : {

    },
    "Your age will be public." : {

    }
  },
  "version" : "1.0"
}
"""#

    func load() {
        do {
            if let data = json.data(using: .utf8),
               let dict = try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any] {
                languageDictionary = dict
                print("Dict", dict)
            }

        } catch {
            print("Serialization error:", error.localizedDescription)
        }
    }

    func load(file url: URL) {
        fileURL = url

        do {
            if let data = try? Data(contentsOf: url),
               let dict = try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any] {
                languageDictionary = dict
                print("Dict", dict)

                parse()
            }

        } catch {
            print("Serialization error:", error.localizedDescription)
        }
    }

    func save() {
        guard let fileURL else {
            print("No file URL set.")
            return
        }

        do {
            let jsonData = try JSONSerialization.data(
                withJSONObject: languageDictionary,
                options: .prettyPrinted
            )
//
//            if !isTesting {
//                try jsonData.write(to: fileURL)
//            }

            print("SAVED", String(data: jsonData, encoding: .utf8))
        } catch {
            print("An error occurred while saving the file: \(error)")
        }
    }

    func parse() {
        stringsToTranslate = []

        if let strings = languageDictionary["strings"] as? [String: Any] {
            for (key, value) in strings {
//                if let stringValue = value as? String {
//                    stringsToTranslate[key] = stringValue
//                }
                guard let value = value as? [String: Any] else { continue }
                stringsToTranslate.append(key)
                shouldTranslate.append(value["shouldTranslate"] as? Bool ?? true)
            }
        }
    }
}
// swiftlint:disable:this file_length
