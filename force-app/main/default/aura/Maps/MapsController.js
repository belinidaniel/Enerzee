({
    doInit: function (component, event, helper) {
        const action = component.get("c.getLocation");
        
        action.setParams({
            recordId: component.get("v.recordId")
        });
        
        action.setCallback(this, function (response) {
            const state = response.getState();
            if (state === "SUCCESS") {
                const locationData = response.getReturnValue();
                
                if (locationData.Latitude && locationData.Longitude) {
                    component.set("v.mapMarkers", [
                        {
                            location: {
                                Latitude: locationData.Latitude,
                                Longitude: locationData.Longitude
                            },
                            title: locationData.Name,
                            description: "Localização Fixa"
                        }
                    ]);
                }
            } else if (state === "ERROR") {
                const errors = response.getError();
                console.error("Erro ao buscar localização: ", errors);
            }
        });
        
        $A.enqueueAction(action);
    },

    openGoogleMaps: function(component, event, helper) {
        var mapMarkers = component.get("v.mapMarkers");

        if (!mapMarkers || mapMarkers.length === 0) {
            console.log("Nenhum marcador disponível");
            return;
        }

        var marker = mapMarkers[0];
        var latitude = marker.location.Latitude;
        var longitude = marker.location.Longitude;

        if (!latitude || !longitude) {
            console.log("Latitude ou longitude inválida");
            return;
        }

        var googleMapsUrl = "https://www.google.com/maps?q=" + latitude + "," + longitude;
        window.open(googleMapsUrl, "_blank");
    }
})