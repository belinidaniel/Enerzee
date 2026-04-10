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

  public class SectionConfig implements Comparable {
    public String coverKey;
    public String scenario;
    public String paymentType;
    public String sectionName;
    public Integer sortOrder;
    public Boolean active;

    public Integer compareTo(Object otherObject) {
      SectionConfig other = (SectionConfig) otherObject;
      Integer left = sortOrder == null ? 0 : sortOrder;
      Integer right = other.sortOrder == null ? 0 : other.sortOrder;
      if (left == right) {
        return String.valueOf(sectionName)
          .compareTo(String.valueOf(other.sectionName));
      }
      return left < right ? -1 : 1;
    }
  }

  @TestVisible
  private static List<TagConfig> testTagConfigs;
  @TestVisible
  private static List<SectionConfig> testSectionConfigs;

  @TestVisible
  public static void setTestTagConfigs(List<TagConfig> configs) {
    testTagConfigs = configs;
  }

  @TestVisible
  public static void setTestSectionConfigs(List<SectionConfig> configs) {
    testSectionConfigs = configs;
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

  public static List<String> getSectionsToShow(
    String coverKey,
    String scenario,
    String paymentType
  ) {
    List<SectionConfig> exactMatches = new List<SectionConfig>();
    List<SectionConfig> genericMatches = new List<SectionConfig>();
    for (SectionConfig config : loadSectionConfigs()) {
      if (!matchesCover(config.coverKey, coverKey) || config.active != true) {
        continue;
      }
      if (!matchesScenario(config.scenario, scenario, false)) {
        continue;
      }
      if (String.isBlank(config.paymentType)) {
        genericMatches.add(config);
      } else if (matchesPaymentType(config.paymentType, paymentType)) {
        exactMatches.add(config);
      }
    }

    List<SectionConfig> selected = !exactMatches.isEmpty()
      ? exactMatches
      : genericMatches;
    selected.sort();

    List<String> sections = new List<String>();
    for (SectionConfig config : selected) {
      sections.add(config.sectionName);
    }
    return sections;
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

  private static List<SectionConfig> loadSectionConfigs() {
    if (testSectionConfigs != null) {
      return new List<SectionConfig>(testSectionConfigs);
    }

    List<SectionConfig> results = new List<SectionConfig>();
    for (
      ProposalSectionRule__mdt record : ProposalSectionRule__mdt.getAll()
        .values()
    ) {
      SectionConfig config = new SectionConfig();
      config.coverKey = record.CoverKey__c;
      config.scenario = normalize(record.Scenario__c);
      config.paymentType = normalize(record.PaymentType__c);
      config.sectionName = record.SectionName__c;
      config.sortOrder = record.SortOrder__c == null
        ? 0
        : Integer.valueOf(record.SortOrder__c);
      config.active = record.Active__c;
      results.add(config);
    }
    return results;
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
