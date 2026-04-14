/**
 * @description       :
 * @author            : Daniel Belini
 * @group             :
 * @last modified on  : 04-10-2026
 * @last modified by  : Daniel Belini
 * @test              : ProposalConsoleControllerApiTest, ProposalEngineSupportTest
 **/
public with sharing class ProposalConfigurationService {
  public static final String SCENARIO_ALL = 'ALL';
  public static final String SCENARIO_INITIAL = 'INITIAL';
  public static final String SCENARIO_INITIAL_FINANCING = 'INITIAL_FINANCING';
  public static final String SCENARIO_PAYMENT_SELECTED = 'PAYMENT_SELECTED';
  public static final String FORMAT_RAW = 'RAW';

  public class TagConfig implements Comparable {
    public String coverKey;
    public String tagKey;
    public String sourcePath;
    public String scenario;
    public String paymentType;
    public String formatValue;
    public String defaultValue;
    public Boolean required;
    public Integer sortOrder;
    public Boolean active;

    public Integer compareTo(Object otherObject) {
      TagConfig other = (TagConfig) otherObject;
      Integer left = sortOrder == null ? 0 : sortOrder;
      Integer right = other.sortOrder == null ? 0 : other.sortOrder;
      if (left == right) {
        return String.valueOf(tagKey).compareTo(String.valueOf(other.tagKey));
      }
      return left < right ? -1 : 1;
    }
  }

  @TestVisible
  private static List<TagConfig> testTagConfigs;
  @TestVisible
  private static Map<String, List<String>> testSectionsByKey;

  @TestVisible
  public static void setTestTagConfigs(List<TagConfig> configs) {
    testTagConfigs = configs;
  }

  @TestVisible
  public static void setTestSectionsByKey(
    Map<String, List<String>> sectionsByKey
  ) {
    testSectionsByKey = sectionsByKey;
  }

  public static List<TagConfig> getTagConfigs(
    String coverKey,
    String scenario,
    String paymentType
  ) {
    List<TagConfig> candidates = new List<TagConfig>();
    for (TagConfig config : loadTagConfigs()) {
      if (!matchesCover(config.coverKey, coverKey) || config.active != true) {
        continue;
      }
      if (!matchesScenario(config.scenario, scenario, true)) {
        continue;
      }
      if (!matchesPaymentType(config.paymentType, paymentType)) {
        continue;
      }
      if (String.isBlank(config.formatValue)) {
        config.formatValue = FORMAT_RAW;
      }
      candidates.add(config);
    }
    candidates.sort();
    return candidates;
  }

  public static final String PAYMENT_TYPE_OTHERS = 'OTHERS';

  public static List<String> getSectionsToShow(
    String coverKey,
    String scenario,
    String paymentType
  ) {
    Map<String, List<String>> sectionsByKey = loadSectionsByKey(coverKey);
    if (String.isBlank(paymentType)) {
      String scenarioKey = normalize(scenario) == SCENARIO_INITIAL_FINANCING
        ? SCENARIO_INITIAL_FINANCING
        : SCENARIO_INITIAL;
      if (sectionsByKey.containsKey(scenarioKey)) {
        return sectionsByKey.get(scenarioKey);
      }
      if (sectionsByKey.containsKey(SCENARIO_INITIAL)) {
        return sectionsByKey.get(SCENARIO_INITIAL);
      }
      return new List<String>();
    }
    if (sectionsByKey.containsKey(paymentType)) {
      return sectionsByKey.get(paymentType);
    }
    if (sectionsByKey.containsKey(PAYMENT_TYPE_OTHERS)) {
      return sectionsByKey.get(PAYMENT_TYPE_OTHERS);
    }
    if (sectionsByKey.containsKey(SCENARIO_INITIAL)) {
      return sectionsByKey.get(SCENARIO_INITIAL);
    }
    return new List<String>();
  }

  private static List<TagConfig> loadTagConfigs() {
    if (testTagConfigs != null) {
      return new List<TagConfig>(testTagConfigs);
    }

    List<TagConfig> results = new List<TagConfig>();
    for (
      ProposalTagMapping__mdt record : ProposalTagMapping__mdt.getAll().values()
    ) {
      TagConfig config = new TagConfig();
      config.coverKey = record.CoverKey__c;
      config.tagKey = record.TagKey__c;
      config.sourcePath = record.SourcePath__c;
      config.scenario = normalize(record.Scenario__c);
      config.paymentType = normalize(record.PaymentType__c);
      config.formatValue = normalize(record.Format__c);
      config.defaultValue = record.DefaultValue__c;
      config.required = record.Required__c;
      config.sortOrder = record.SortOrder__c == null
        ? 0
        : Integer.valueOf(record.SortOrder__c);
      config.active = record.Active__c;
      results.add(config);
    }
    return results;
  }

  private static Map<String, List<String>> loadSectionsByKey(String coverKey) {
    if (testSectionsByKey != null) {
      return testSectionsByKey;
    }

    Map<String, List<String>> result = new Map<String, List<String>>();
    for (
      ProposalSectionRule__mdt record : ProposalSectionRule__mdt.getAll()
        .values()
    ) {
      if (record.Active__c != true) {
        continue;
      }
      if (normalize(record.CoverKey__c) != normalize(coverKey)) {
        continue;
      }
      if (String.isBlank(record.SectionsJson__c)) {
        continue;
      }
      String key = String.isBlank(record.PaymentType__c)
        ? SCENARIO_INITIAL
        : record.PaymentType__c.trim();
      List<String> sections = (List<String>) JSON.deserialize(
        record.SectionsJson__c,
        List<String>.class
      );
      result.put(key, sections);
    }
    return result;
  }

  private static Boolean matchesCover(String configCoverKey, String coverKey) {
    return normalize(configCoverKey) == normalize(coverKey);
  }

  private static Boolean matchesScenario(
    String configScenario,
    String scenario,
    Boolean allowAll
  ) {
    String normalizedScenario = normalize(configScenario);
    if (allowAll && normalizedScenario == SCENARIO_ALL) {
      return true;
    }
    return normalizedScenario == normalize(scenario);
  }

  private static Boolean matchesPaymentType(
    String configPaymentType,
    String paymentType
  ) {
    return String.isBlank(configPaymentType) ||
      normalize(configPaymentType) == normalize(paymentType);
  }

  private static String normalize(String value) {
    return String.isBlank(value) ? null : value.trim().toUpperCase();
  }
}
