/**
 * @description       : REST endpoint for Product2 + PricebookEntry management. A single PATCH payload handles create,
 *                       update, and deactivate. Business logic lives in ProductBO.processUpdates().
 * @author            : Daniel Belini
 * @group             :
 * @last modified on  : 03-17-2026
 * @last modified by  : Daniel Belini
 * @test              : ProductUpdateEntryRestTest
 **/
@RestResource(urlMapping='/ProductUpdateEntry/*')
global with sharing class ProductUpdateEntryRest {
  global class ResponseWrapper {
    public String status;
    public String message;
    public List<Map<String, String>> results;
  }

  @HttpPatch
  global static void updateProductPrices() {
    RestRequest req = RestContext.request;
    String body = req.requestBody != null ? req.requestBody.toString() : '';
    ResponseWrapper resp = new ResponseWrapper();
    resp.results = new List<Map<String, String>>();

    try {
      List<ProductBO.ProductPayload> updates = parsePayload(body);
      if (updates.isEmpty()) {
        resp.status = 'Error';
        resp.message = 'No products provided.';
        setResponse(resp);
        return;
      }
      resp.results = ProductBO.processUpdates(updates);
      resp.status = 'Success';
      resp.message = 'Products processed.';
    } catch (Exception e) {
      resp.status = 'Error';
      resp.message = e.getMessage();
    }
    setResponse(resp);
  }

  // ─── Helpers ─────────────────────────────────────────────────────────────────

  private static void setResponse(ResponseWrapper resp) {
    RestContext.response.responseBody = Blob.valueOf(
      JSON.serializePretty(resp)
    );
  }

  private static List<ProductBO.ProductPayload> parsePayload(String body) {
    List<ProductBO.ProductPayload> out = new List<ProductBO.ProductPayload>();
    if (String.isBlank(body)) {
      return out;
    }
    String trimmed = body.trim();
    try {
      if (trimmed.startsWith('[')) {
        out = (List<ProductBO.ProductPayload>) JSON.deserialize(
          trimmed,
          List<ProductBO.ProductPayload>.class
        );
      } else if (trimmed.startsWith('{')) {
        out.add(
          (ProductBO.ProductPayload) JSON.deserialize(
            trimmed,
            ProductBO.ProductPayload.class
          )
        );
      }
    } catch (Exception ex) {
      // Invalid JSON — empty list triggers 'No products provided.' error response
    }
    List<ProductBO.ProductPayload> clean = new List<ProductBO.ProductPayload>();
    for (ProductBO.ProductPayload u : out) {
      if (u != null) {
        clean.add(u);
      }
    }
    return clean;
  }

  @TestVisible
  private static void callPatch(String jsonPayload) {
    RestRequest req = new RestRequest();
    req.requestBody = Blob.valueOf(jsonPayload);
    RestContext.request = req;
    if (RestContext.response == null) {
      RestContext.response = new RestResponse();
    }
    updateProductPrices();
  }
}
