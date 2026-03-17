/**
 * @description       :
 * @author            : Daniel Belini
 * @group             :
 * @last modified on  : 03-15-2026
 * @last modified by  : Daniel Belini
 * @test              : N/A - classe de apoio a testes
 **/
@isTest
public class TestFactory {
  private static Integer uniqueCounter = 0;

  public static SObject createSObject(SObject sObj) {
    // Check what type of object we are creating and add any defaults that are needed.
    String objectName = String.valueOf(sObj.getSObjectType());
    // Construct the default values class. Salesforce doesn't allow '__' in class names
    String defaultClassName =
      objectName.replaceAll('__(c|C)$|__', '') + 'Defaults';
    // If there is a class that exists for the default values, then use them
    if (Type.forName('TestFactoryDefaults.' + defaultClassName) != null) {
      sObj = createSObject(sObj, 'TestFactoryDefaults.' + defaultClassName);
    }
    return sObj;
  }

  public static SObject createSObject(SObject sObj, Boolean doInsert) {
    SObject retObject = createSObject(sObj);
    if (doInsert) {
      prepareForInsert(retObject);
      insert retObject;
    }
    return retObject;
  }

  public static SObject createSObject(SObject sObj, String defaultClassName) {
    // Create an instance of the defaults class so we can get the Map of field defaults
    Type t = Type.forName(defaultClassName);
    if (t == null) {
      throw new TestFactoryException('Invalid defaults class.');
    }
    FieldDefaults defaults = (FieldDefaults) t.newInstance();
    addFieldDefaults(sObj, defaults.getFieldDefaults());
    return sObj;
  }

  public static SObject createSObject(
    SObject sObj,
    String defaultClassName,
    Boolean doInsert
  ) {
    SObject retObject = createSObject(sObj, defaultClassName);
    if (doInsert) {
      prepareForInsert(retObject);
      insert retObject;
    }
    return retObject;
  }

  public static SObject[] createSObjectList(
    Sobject sObj,
    Integer numberOfObjects
  ) {
    return createSObjectList(sObj, numberOfObjects, (String) null);
  }

  public static SObject[] createSObjectList(
    SObject sObj,
    Integer numberOfObjects,
    Boolean doInsert
  ) {
    SObject[] retList = createSObjectList(sObj, numberOfObjects, (String) null);
    if (doInsert) {
      prepareForInsert(retList);
      insert retList;
    }
    return retList;
  }

  public static SObject[] createSObjectList(
    SObject sObj,
    Integer numberOfObjects,
    String defaultClassName,
    Boolean doInsert
  ) {
    SObject[] retList = createSObjectList(
      sObj,
      numberOfObjects,
      defaultClassName
    );
    if (doInsert) {
      prepareForInsert(retList);
      insert retList;
    }
    return retList;
  }

  public static SObject[] createSObjectList(
    Sobject sObj,
    Integer numberOfObjects,
    String defaultClassName
  ) {
    SObject[] sObjs = new List<SObject>{};
    SObject newObj;

    // Get one copy of the object
    if (defaultClassName == null) {
      newObj = createSObject(sObj);
    } else {
      newObj = createSObject(sObj, defaultClassName);
    }

    // Get the name field for the object
    String nameField = String.valueOf(nameFieldMap.get(sObj.getSObjectType()));
    if (nameField == null) {
      nameField = 'Name';
    }
    Boolean nameIsAutoNumber = sObj.getSobjectType()
      .getDescribe()
      .fields.getMap()
      .get(nameField)
      .getDescribe()
      .isAutoNumber();

    // Clone the object the number of times requested. Increment the name field so each record is unique
    for (Integer i = 0; i < numberOfObjects; i++) {
      SObject clonedSObj = newObj.clone(false, true);
      if (!nameIsAutoNumber) {
        clonedSObj.put(nameField, (String) clonedSObj.get(nameField) + ' ' + i);
      }
      sObjs.add(clonedSObj);
    }
    return sObjs;
  }

  private static void addFieldDefaults(
    SObject sObj,
    Map<Schema.SObjectField, Object> defaults
  ) {
    // Loop through the map of fields and if they weren't specifically assigned, fill them.
    Map<String, Object> populatedFields = sObj.getPopulatedFieldsAsMap();
    for (Schema.SObjectField field : defaults.keySet()) {
      if (!populatedFields.containsKey(String.valueOf(field))) {
        sObj.put(field, defaults.get(field));
      }
    }
  }

  public static String nextUniqueValue(String prefix) {
    uniqueCounter++;
    String safePrefix = String.isBlank(prefix) ? 'TEST' : prefix;
    return safePrefix +
      '_' +
      String.valueOf(DateTime.now().getTime()) +
      '_' +
      String.valueOf(uniqueCounter);
  }

  private static void prepareForInsert(SObject sObj) {
    if (sObj == null) {
      return;
    }

    if (sObj.getSObjectType() == Product2.SObjectType) {
      Product2 product = (Product2) sObj;

      String externalId = (String) product.get('ExternalId__c');
      String productCode = product.ProductCode;

      if (String.isBlank(externalId)) {
        externalId = nextUniqueValue('PROD');
        product.put('ExternalId__c', externalId);
      }

      if (String.isBlank(productCode)) {
        product.ProductCode = externalId;
      }

      if (String.isBlank(product.Name)) {
        product.Name = 'Product ' + product.ProductCode;
      }
    }
  }

  private static void prepareForInsert(SObject[] sObjects) {
    if (sObjects == null) {
      return;
    }

    for (SObject sObj : sObjects) {
      prepareForInsert(sObj);
    }
  }

  // When we create a list of SObjects, we need to have a unique field for the insert if there isn't an autonumber field.
  // Usually we use the Name field, but some objects don't have a name field.
  private static Map<Schema.SObjectType, Schema.SObjectField> nameFieldMap = new Map<Schema.SObjectType, Schema.SObjectField>{
    Lead.sObjectType => Lead.LastName,
    Contact.sObjectType => Contact.LastName,
    Case.sObjectType => Case.CaseNumber //this is the autonumber field
  };

  public class TestFactoryException extends Exception {
  }

  // Use the FieldDefaults interface to set up values you want to default in for all objects.
  public interface FieldDefaults {
    Map<Schema.SObjectField, Object> getFieldDefaults();
  }
}
