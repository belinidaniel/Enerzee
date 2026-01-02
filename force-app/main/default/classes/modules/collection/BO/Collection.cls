public with sharing class Collection {

	private List<SObject> records;

	public static Collection of(Iterable<SObject> records) {
		return new Collection(records);
	}

	public static Collection of(Set<SObject> records) {
		return new Collection(new List<SObject>(records));
	}

	private Collection(Iterable<SObject> records) {
		this.records = new List<SObject>();
		Iterator<SObject> iter = records.iterator();
		while (iter.hasNext()) {
			this.records.add(iter.next());
		}
	}
	public List<Id> pluckIds() {
		List<Id> results = new List<Id>();
		for (SObject rec : records) {
			results.add(rec.Id);
		}
		return results;
	}

	public List<String> pluckNotNullStrings(Schema.SObjectField field) {
		List<String> results = new List<String>();
		for (SObject rec : records) {
			if((String)rec.get(field) != null){
				results.add((String)rec.get(field));
			}
		}
		return results;
	}
}