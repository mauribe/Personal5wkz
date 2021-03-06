public class MyProgrammingLanguage {
	// This class is a simple wrapper around the Programming_Language__c object
	// 	to include an extra property on the object
	
    public Programming_Language__c theRecord {get; set;} 	// the record being wrapped around
    public Boolean checked {get; set;}				// for data-binding to a checkbox

    // constructor for NEW Programming_Language__c records
    public MyProgrammingLanguage(){
        theRecord = new Programming_Language__c();
        checked = false;
    }
    
    // constructor used for existing Programming_Language__c records
    public MyProgrammingLanguage(Programming_Language__c p){
        theRecord = p;
        checked = false;
    }

}