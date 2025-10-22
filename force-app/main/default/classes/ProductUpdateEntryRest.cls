/**
 * @description       :
 * @author            : Daniel Belini
 * @group             :
 * @last modified on  : 08-29-2025
 * @last modified by  : Daniel Belini
**/
@RestResource(urlMapping = '/ProductUpdateEntry/*')
global with sharing class ProductUpdateEntryRest {

    global class ProductPriceUpdate {
        public String externalId;   // ID externo da integração (salvo em ExternalId__c / Id_Externo__c)
        public String productCode;  // mapeado para Product2.ProductCode (chave principal)
        public String name;
        public Decimal price;
        public String productFamily;
    }
    global class ResponseWrapper {
        public String status;
        public String message;
        public List<Map<String,String>> results;
    }

    @HttpPatch
    global static void updateProductPrices() {
        RestRequest req = RestContext.request;
        String body = req.requestBody != null ? req.requestBody.toString() : '';
        ResponseWrapper resp = new ResponseWrapper();
        resp.results = new List<Map<String,String>>();

        try {
            List<ProductPriceUpdate> updates = parsePayload(body);
            if (updates.isEmpty()) {
                resp.status = 'Error';
                resp.message = 'No products provided.';
                RestContext.response.responseBody = Blob.valueOf(JSON.serializePretty(resp));
                return;
            }

            Id stdPbId = Test.isRunningTest()
                ? Test.getStandardPricebookId()
                : [SELECT Id FROM Pricebook2 WHERE IsStandard = true LIMIT 1].Id;

            // Coleta de chaves
            Set<String> productCodes = new Set<String>();
            Set<String> extIds       = new Set<String>();
            Set<String> names        = new Set<String>();
            for (ProductPriceUpdate u : updates) {
                if (u == null) continue;
                if (!String.isBlank(u.productCode)) productCodes.add(u.productCode.trim());
                if (!String.isBlank(u.externalId))  extIds.add(u.externalId.trim());
                if (!String.isBlank(u.name))        names.add(u.name.trim());
            }

            Map<Id, Product2> idToProd = new Map<Id, Product2>();
            Map<String, List<Product2>> codeToProds  = new Map<String, List<Product2>>();
            Map<String, List<Product2>> nameToProds  = new Map<String, List<Product2>>();
            Map<String, List<Product2>> extIdToProds = new Map<String, List<Product2>>();

            if (!productCodes.isEmpty() || !names.isEmpty() || !extIds.isEmpty()) {
                for (Product2 p : [
                    SELECT Id, Name, Family, ProductCode, IsActive, ExternalId__c, Id_Externo__c
                    FROM Product2
                    WHERE (ProductCode IN :productCodes OR Name IN :names OR ExternalId__c IN :extIds)
                ]) {
                    idToProd.put(p.Id, p);

                    if (!String.isBlank(p.ProductCode)) {
                        if (!codeToProds.containsKey(p.ProductCode)) codeToProds.put(p.ProductCode, new List<Product2>());
                        codeToProds.get(p.ProductCode).add(p);
                    }
                    if (!String.isBlank(p.Name)) {
                        if (!nameToProds.containsKey(p.Name)) nameToProds.put(p.Name, new List<Product2>());
                        nameToProds.get(p.Name).add(p);
                    }
                    String extVal = (String)p.get('ExternalId__c');
                    if (!String.isBlank(extVal)) {
                        if (!extIdToProds.containsKey(extVal)) extIdToProds.put(extVal, new List<Product2>());
                        extIdToProds.get(extVal).add(p);
                    }
                }
            }

            // Preparar inserts para produtos ausentes
            List<Product2> productsToInsert = new List<Product2>();
            Map<String, Product2> newByProductCode = new Map<String, Product2>();
            Map<String, Product2> newByExternalId  = new Map<String, Product2>();

            for (ProductPriceUpdate u : updates) {
                if (u == null) continue;
                String code = String.isBlank(u.productCode) ? null : u.productCode.trim();
                String ext  = String.isBlank(u.externalId)  ? null : u.externalId.trim();

                Boolean existsByCode = (code != null && codeToProds.containsKey(code));
                Boolean existsByExt  = (!existsByCode && ext != null && extIdToProds.containsKey(ext));

                if (!existsByCode && !existsByExt) {
                    // define ProductCode: prioriza productCode; fallback para externalId
                    String finalCode = (code != null) ? code : ext;
                    if (String.isBlank(finalCode)) {
                        // sem identificador suficiente, pula (será reportado depois)
                        continue;
                    }

                    Product2 newProd = new Product2(
                        ProductCode    = finalCode,
                        Name           = String.isBlank(u.name) ? finalCode : u.name,
                        Family         = u.productFamily,
                        IsActive       = true,
                        ExternalId__c  = ext,
                        Id_Externo__c  = ext
                    );
                    productsToInsert.add(newProd);
                    if (code != null) newByProductCode.put(code, newProd);
                    if (ext  != null) newByExternalId.put(ext, newProd);
                }
            }

            if (!productsToInsert.isEmpty()) {
                insert productsToInsert;

                // Reindexa mapas após insert
                for (Product2 p : productsToInsert) {
                    idToProd.put(p.Id, p);

                    if (!String.isBlank(p.ProductCode)) {
                        if (!codeToProds.containsKey(p.ProductCode)) codeToProds.put(p.ProductCode, new List<Product2>());
                        codeToProds.get(p.ProductCode).add(p);
                    }
                    if (!String.isBlank(p.Name)) {
                        if (!nameToProds.containsKey(p.Name)) nameToProds.put(p.Name, new List<Product2>());
                        nameToProds.get(p.Name).add(p);
                    }
                    String extVal = (String)p.get('ExternalId__c');
                    if (!String.isBlank(extVal)) {
                        if (!extIdToProds.containsKey(extVal)) extIdToProds.put(extVal, new List<Product2>());
                        extIdToProds.get(extVal).add(p);
                    }
                }
            }

            // Matching e coleta de preços
            List<Id> matchedProdIds = new List<Id>();
            Map<Id, Decimal> prodIdToPrice = new Map<Id, Decimal>();
            Map<Id, Product2> prodIdToChosen = new Map<Id, Product2>();

            for (ProductPriceUpdate u : updates) {
                if (u == null || u.price == null) continue;

                Product2 chosen;
                String code = String.isBlank(u.productCode) ? null : u.productCode.trim();
                String ext  = String.isBlank(u.externalId)  ? null : u.externalId.trim();

                if (code != null && codeToProds.containsKey(code)) {
                    chosen = chooseByFamily(codeToProds.get(code), u.productFamily);
                }
                if (chosen == null && !String.isBlank(u.name) && nameToProds.containsKey(u.name.trim())) {
                    chosen = chooseByFamily(nameToProds.get(u.name.trim()), u.productFamily);
                }
                if (chosen == null && ext != null && extIdToProds.containsKey(ext)) {
                    chosen = chooseByFamily(extIdToProds.get(ext), u.productFamily);
                }
                if (chosen == null) {
                    if (code != null && newByProductCode.containsKey(code)) chosen = newByProductCode.get(code);
                    else if (ext != null && newByExternalId.containsKey(ext)) chosen = newByExternalId.get(ext);
                }

                if (chosen != null) {
                    matchedProdIds.add(chosen.Id);
                    prodIdToPrice.put(chosen.Id, u.price);
                    prodIdToChosen.put(chosen.Id, chosen);
                } else {
                    resp.results.add(new Map<String,String>{
                        'name'        => String.valueOf(u.name),
                        'productCode' => String.valueOf(u.productCode),
                        'externalId'  => String.valueOf(u.externalId),
                        'family'      => String.valueOf(u.productFamily),
                        'status'      => 'NotFound',
                        'message'     => 'No matching Product2 by productCode, Name+Family, or ExternalId__c.'
                    });
                }
            }

            if (matchedProdIds.isEmpty()) {
                resp.status = 'Error';
                resp.message = 'No matching Product2 found for any payload items.';
                RestContext.response.responseBody = Blob.valueOf(JSON.serializePretty(resp));
                return;
            }

            // PBE: cria/atualiza no PB padrão
            Map<Id, PricebookEntry> prodIdToPbe = new Map<Id, PricebookEntry>();
            for (PricebookEntry pbe : [
                SELECT Id, Product2Id, Pricebook2Id, UnitPrice, IsActive
                FROM PricebookEntry
                WHERE Pricebook2Id = :stdPbId AND Product2Id IN :matchedProdIds
            ]) {
                prodIdToPbe.put(pbe.Product2Id, pbe);
            }

            List<PricebookEntry> toInsert = new List<PricebookEntry>();
            List<PricebookEntry> toUpdate = new List<PricebookEntry>();

            for (Id pid : matchedProdIds) {
                Decimal newPrice = prodIdToPrice.get(pid);
                if (prodIdToPbe.containsKey(pid)) {
                    PricebookEntry pbe = prodIdToPbe.get(pid);
                    pbe.UnitPrice = newPrice;
                    pbe.IsActive  = true;
                    toUpdate.add(pbe);
                } else {
                    toInsert.add(new PricebookEntry(
                        Pricebook2Id = stdPbId,
                        Product2Id   = pid,
                        UnitPrice    = newPrice,
                        IsActive     = true
                    ));
                }
            }

            if (!toInsert.isEmpty()) insert toInsert;
            if (!toUpdate.isEmpty()) update toUpdate;

            for (PricebookEntry p : toInsert) {
                Product2 prod = idToProd.get(p.Product2Id);
                resp.results.add(new Map<String,String>{
                    'name'            => prod != null ? prod.Name : null,
                    'productCode'     => prod != null ? prod.ProductCode : null,
                    'externalId'      => prod != null ? (String)prod.get('ExternalId__c') : null,
                    'family'          => prod != null ? prod.Family : null,
                    'status'          => 'Created',
                    'unitPrice'       => String.valueOf(p.UnitPrice),
                    'productId'       => prod != null ? prod.Id : null,
                    'pricebookEntryId'=> p.Id
                });
            }
            for (PricebookEntry p : toUpdate) {
                Product2 prod = idToProd.get(p.Product2Id);
                resp.results.add(new Map<String,String>{
                    'name'            => prod != null ? prod.Name : null,
                    'productCode'     => prod != null ? prod.ProductCode : null,
                    'externalId'      => prod != null ? (String)prod.get('ExternalId__c') : null,
                    'family'          => prod != null ? prod.Family : null,
                    'status'          => 'Updated',
                    'unitPrice'       => String.valueOf(p.UnitPrice),
                    'productId'       => prod != null ? prod.Id : null,
                    'pricebookEntryId'=> p.Id
                });
            }

            resp.status = 'Success';
            resp.message = 'Products processed.';
            RestContext.response.responseBody = Blob.valueOf(JSON.serializePretty(resp));
        } catch (Exception e) {
            ResponseWrapper err = new ResponseWrapper();
            err.status = 'Error';
            err.message = 'Error: ' + e.getMessage();
            err.results = new List<Map<String,String>>();
            RestContext.response.responseBody = Blob.valueOf(JSON.serializePretty(err));
        }
    }

    // --- Helpers ---

    private static List<ProductPriceUpdate> parsePayload(String body) {
        List<ProductPriceUpdate> out = new List<ProductPriceUpdate>();
        if (String.isBlank(body)) return out;

        String trimmed = body.trim();
        try {
            if (trimmed.startsWith('[')) {
                out = (List<ProductPriceUpdate>) JSON.deserialize(trimmed, List<ProductPriceUpdate>.class);
            } else if (trimmed.startsWith('{')) {
                out.add((ProductPriceUpdate) JSON.deserialize(trimmed, ProductPriceUpdate.class));
            } else {
                for (String line : trimmed.split('[\\r\\n]+')) {
                    String l = line != null ? line.trim() : '';
                    if (l.startsWith('{') && l.endsWith('}')) {
                        out.add((ProductPriceUpdate) JSON.deserialize(l, ProductPriceUpdate.class));
                    }
                }
            }
        } catch (Exception ex) {
            // silencioso
        }
        List<ProductPriceUpdate> clean = new List<ProductPriceUpdate>();
        for (ProductPriceUpdate u : out) if (u != null) clean.add(u);
        return clean;
    }

    private static Product2 chooseByFamily(List<Product2> candidates, String desiredFamily) {
        if (candidates == null || candidates.isEmpty()) return null;
        if (!String.isBlank(desiredFamily)) {
            for (Product2 p : candidates) {
                if (p.Family == desiredFamily) return p;
            }
        }
        return candidates[0];
    }

    // Test helper
    public static void testUpdateProductPrices(String jsonPayload) {
        RestRequest req = new RestRequest();
        req.requestBody = Blob.valueOf(jsonPayload);
        RestContext.request = req;
        if (RestContext.response == null) RestContext.response = new RestResponse();

        updateProductPrices();

        String respBody = 'No response set.';
        if (RestContext.response != null && RestContext.response.responseBody != null) {
            respBody = RestContext.response.responseBody.toString();
        }
        System.debug('Response: ' + respBody);
    }
}