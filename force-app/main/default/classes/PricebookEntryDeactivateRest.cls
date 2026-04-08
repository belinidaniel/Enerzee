/**
 * @description       : Deactivates standard price book entries by externalId.
 * @author            : Codex
 * @group             :
 * @last modified on  : 04-07-2026
 * @last modified by  : Daniel Belini
 * @test              : PricebookEntryDeactivateRestTest
 **/
@RestResource(urlMapping='/PricebookEntryDeactivate/*')
global with sharing class PricebookEntryDeactivateRest {
  global class DeactivateItem {
    public String externalId;
  }

  global class ResponseWrapper {
    public String status;
    public String message;
    public List<Map<String, String>> results;
  }

  @HttpPost
  global static void deactivatePricebookEntries() {
    RestRequest req = RestContext.request;
    String body = req.requestBody != null ? req.requestBody.toString() : '';
    ResponseWrapper response = new ResponseWrapper();
    response.results = new List<Map<String, String>>();

    try {
      List<DeactivateItem> items = parsePayload(body);
      if (items.isEmpty()) {
        response.status = 'Error';
        response.message = 'No pricebook entries provided.';
        RestContext.response.responseBody = Blob.valueOf(
          JSON.serializePretty(response)
        );
        return;
      }

      Id standardPricebookId = Test.isRunningTest()
        ? Test.getStandardPricebookId()
        : [SELECT Id FROM Pricebook2 WHERE IsStandard = TRUE LIMIT 1].Id;

      Set<String> externalIds = new Set<String>();
      for (DeactivateItem item : items) {
        if (item != null && !String.isBlank(item.externalId)) {
          externalIds.add(item.externalId.trim());
        }
      }

      Map<String, PricebookEntry> externalIdToPricebookEntry = new Map<String, PricebookEntry>();
      if (!externalIds.isEmpty()) {
        for (PricebookEntry pricebookEntry : [
          SELECT
            Id,
            Product2Id,
            IsActive,
            ExternalId__c,
            Product2.Name,
            Product2.ProductCode
          FROM PricebookEntry
          WHERE
            Pricebook2Id = :standardPricebookId
            AND ExternalId__c IN :externalIds
        ]) {
          externalIdToPricebookEntry.put(
            pricebookEntry.ExternalId__c,
            pricebookEntry
          );
        }
      }

      List<PricebookEntry> toUpdate = new List<PricebookEntry>();
      List<Integer> updateIndexes = new List<Integer>();
      Integer successCount = 0;

      for (Integer idx = 0; idx < items.size(); idx++) {
        DeactivateItem item = items[idx];
        if (item == null || String.isBlank(item.externalId)) {
          response.results.add(
            new Map<String, String>{
              'externalId' => item != null ? item.externalId : null,
              'status' => 'Error',
              'message' => 'Missing externalId.'
            }
          );
          continue;
        }

        String normalizedExternalId = item.externalId.trim();
        PricebookEntry pricebookEntry = externalIdToPricebookEntry.get(
          normalizedExternalId
        );
        if (pricebookEntry == null) {
          response.results.add(
            new Map<String, String>{
              'externalId' => normalizedExternalId,
              'status' => 'NotFound',
              'message' => 'PricebookEntry not found.'
            }
          );
          continue;
        }

        if (!pricebookEntry.IsActive) {
          response.results.add(
            new Map<String, String>{
              'externalId' => normalizedExternalId,
              'status' => 'AlreadyInactive',
              'message' => 'PricebookEntry is already inactive.',
              'productId' => pricebookEntry.Product2Id,
              'productCode' => pricebookEntry.Product2.ProductCode,
              'name' => pricebookEntry.Product2.Name,
              'Id' => pricebookEntry.Id
            }
          );
          continue;
        }

        pricebookEntry.IsActive = false;
        toUpdate.add(pricebookEntry);
        updateIndexes.add(idx);
      }

      if (!toUpdate.isEmpty()) {
        Database.SaveResult[] updateResults = Database.update(toUpdate, false);
        for (Integer idx = 0; idx < updateResults.size(); idx++) {
          DeactivateItem item = items[updateIndexes[idx]];
          PricebookEntry pricebookEntry = toUpdate[idx];
          if (updateResults[idx].isSuccess()) {
            successCount++;
            response.results.add(
              new Map<String, String>{
                'externalId' => item.externalId,
                'status' => 'Deactivated',
                'productId' => pricebookEntry.Product2Id,
                'productCode' => pricebookEntry.Product2.ProductCode,
                'name' => pricebookEntry.Product2.Name,
                'Id' => pricebookEntry.Id
              }
            );
            continue;
          }

          response.results.add(
            new Map<String, String>{
              'externalId' => item.externalId,
              'status' => 'Error',
              'message' => firstErrorMessage(updateResults[idx].getErrors()),
              'productId' => pricebookEntry.Product2Id,
              'productCode' => pricebookEntry.Product2.ProductCode,
              'name' => pricebookEntry.Product2.Name,
              'Id' => pricebookEntry.Id
            }
          );
        }
      }

      response.status = successCount > 0 ? 'Success' : 'Error';
      response.message = 'Pricebook entries processed.';
      RestContext.response.responseBody = Blob.valueOf(
        JSON.serializePretty(response)
      );
    } catch (Exception ex) {
      response.status = 'Error';
      response.message = 'Error: ' + ex.getMessage();
      RestContext.response.responseBody = Blob.valueOf(
        JSON.serializePretty(response)
      );
    }
  }

  private static List<DeactivateItem> parsePayload(String body) {
    List<DeactivateItem> parsedItems = new List<DeactivateItem>();
    if (String.isBlank(body)) {
      return parsedItems;
    }

    Object rawPayload = JSON.deserializeUntyped(body);
    if (rawPayload instanceof List<Object>) {
      for (Object rawItem : (List<Object>) rawPayload) {
        if (rawItem instanceof String) {
          DeactivateItem item = new DeactivateItem();
          item.externalId = (String) rawItem;
          parsedItems.add(item);
        } else if (rawItem instanceof Map<String, Object>) {
          DeactivateItem item = new DeactivateItem();
          item.externalId = (String) ((Map<String, Object>) rawItem)
            .get('externalId');
          parsedItems.add(item);
        }
      }
      return parsedItems;
    }

    if (rawPayload instanceof Map<String, Object>) {
      DeactivateItem item = new DeactivateItem();
      item.externalId = (String) ((Map<String, Object>) rawPayload)
        .get('externalId');
      parsedItems.add(item);
      return parsedItems;
    }

    if (rawPayload instanceof String) {
      DeactivateItem item = new DeactivateItem();
      item.externalId = (String) rawPayload;
      parsedItems.add(item);
    }
    return parsedItems;
  }

  private static String firstErrorMessage(Database.Error[] errors) {
    return errors != null &&
      errors.size() > 0
      ? errors[0].getMessage()
      : 'Unknown error';
  }

  public static void testDeactivatePricebookEntries(String jsonPayload) {
    RestRequest request = new RestRequest();
    request.requestBody = Blob.valueOf(jsonPayload);
    RestContext.request = request;
    if (RestContext.response == null) {
      RestContext.response = new RestResponse();
    }

    deactivatePricebookEntries();
  }
}
