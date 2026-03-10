/**
 * @description  REST endpoint para integração de produtos.
 *               PATCH: cria/atualiza/desativa produto + preço no Standard Pricebook.
 *               GET: busca produtos com filtros opcionais.
 **/
@RestResource(urlMapping='/ProductUpdateEntry/*')
global with sharing class ProductUpdateEntryRest {
  @HttpGet
  global static void searchProducts() {
    ProductBO.ProductResponse response;
    try {
      RestRequest request = RestContext.request;
      String productCode = request.params.get('productCode');
      String family = request.params.get('family');
      Boolean isActive = parseBoolean(request.params.get('active'));

      response = ProductBO.searchProducts(productCode, family, isActive);
    } catch (Exception e) {
      response = buildFatalResponse(
        'Error searching products: ' + e.getMessage()
      );
    }
    writeResponse(response);
  }

  @HttpPatch
  global static void updateProducts() {
    ProductBO.ProductResponse response;
    try {
      RestRequest request = RestContext.request;
      String body = request.requestBody == null
        ? null
        : request.requestBody.toString();
      List<ProductBO.ProductPayload> payload = parsePayload(body);
      response = ProductBO.processUpdates(payload);
    } catch (Exception e) {
      response = buildFatalResponse(
        'Error processing payload: ' + e.getMessage()
      );
    }
    writeResponse(response);
  }

  private static List<ProductBO.ProductPayload> parsePayload(String body) {
    if (String.isBlank(body)) {
      return new List<ProductBO.ProductPayload>();
    }

    String trimmed = body.trim();
    if (trimmed.startsWith('[')) {
      return (List<ProductBO.ProductPayload>) JSON.deserialize(
        trimmed,
        List<ProductBO.ProductPayload>.class
      );
    }

    if (trimmed.startsWith('{')) {
      ProductBO.ProductPayload singleItem = (ProductBO.ProductPayload) JSON.deserialize(
        trimmed,
        ProductBO.ProductPayload.class
      );
      return new List<ProductBO.ProductPayload>{ singleItem };
    }

    throw new IllegalArgumentException(
      'Payload must be a JSON object or array.'
    );
  }

  private static Boolean parseBoolean(String value) {
    if (String.isBlank(value)) {
      return null;
    }
    String normalized = value.trim().toLowerCase();
    if (normalized == 'true') {
      return true;
    }
    if (normalized == 'false') {
      return false;
    }
    return null;
  }

  private static ProductBO.ProductResponse buildFatalResponse(String message) {
    ProductBO.ProductResponse response = new ProductBO.ProductResponse();
    response.status = 'Error';
    response.message = message;
    response.successCount = 0;
    response.errorCount = 1;
    response.results = new List<ProductBO.ProductResult>();
    return response;
  }

  private static void writeResponse(ProductBO.ProductResponse response) {
    if (RestContext.response == null) {
      RestContext.response = new RestResponse();
    }
    RestContext.response.responseBody = Blob.valueOf(
      JSON.serializePretty(response)
    );
  }
}
