public class PositionJobPosts {
	
	public static void newPositionPosting(List<Position__c> positions, Boolean isTechnical){
		// Get the list of either Technical Sites or Non-Technical sites
		List<Job_Posting_Site__c> theSites = isTechnical ? [select Id,Technical_Site__c from Job_Posting_Site__c where Technical_Site__c = True and Status__c = 'Active'] : [select Id,Technical_Site__c from Job_Posting_Site__c where Technical_Site__c != True and Status__c = 'Active'];
		List<Job_Posting__c> totalPosts = new List<Job_Posting__c>();		// Total List of Job_Posting__c records to be created
		Map<ID,Position__c> posMap = new Map<ID,Position__c>(positions);	// Map of positionId --> Position__c records
		Map<ID,Set<ID>> existingPostsMap = new Map<ID,Set<ID>>();		// Map of positionId --> Set of existing Job_Posting__c IDs related to the Position
		Job_Posting__c[] postingBatch;						// One batch of Job_Posting__c records to be created
		List<Database.SaveResult> totalResults = new List<Database.SaveResult>();  // Total List of SaveResults
		
		// We're working within the contraint on the max size a List can be: 1000 elements
		// For example: Assuming a max batch of 200 positions in a Trigger, the code below will accommodate up to 
		//	5 Job Site Postings per Position.  Any more than that and we would have to change the logic 
		//	below to create a List of Lists.  We're assuming we're never going to need to 
		//	create over 1000 Job Postings for a single batch of Positions passed into a Trigger.
		if (theSites.size() * positions.size() <= 1000){
			// Create a Map of already existing Job Postings for each Position
			// - Key = Position Id
			// - Value = A Set of Job_Posting_Site Ids that are already associated to the Key
			for(List<Job_Posting__c> existingPosts : [select Id,Position__c,Job_Posting_Site__c from Job_Posting__c where Position__c IN :posMap.keySet()]){
				for(Job_Posting__c post:existingPosts){
					if(!existingPostsMap.containsKey(post.Position__c)){
						// create a new Set for the current Position ID, add the current Post's Site to the Set, then add the Set to the Map
						Set<ID> postIDSet = new Set<ID>{post.Job_Posting_Site__c};
						existingPostsMap.put(post.Position__c,postIDSet);
					} else {
						// extend the Set for the current Position ID
						Set<ID> postIDSet = existingPostsMap.get(post.Position__c);
						if (!postIDSet.contains(post.Job_Posting_Site__c)) {
							postIDSet.add(post.Job_Posting_Site__c);
							existingPostsMap.put(post.Position__c,postIDSet);
						}
					}
				}
			}
			
			// Loop through the Positions and determine which Job_Sites need to be created for each Position, some may already exist like
			//	when a Position's Department has been updated from IT to Engineering (both considered Technical positions)
			for(Position__c position:positions){
				for(Job_Posting_Site__c site:theSites){
					// check if this position has existing Job Postings
					if (existingPostsMap.containsKey(position.Id)){
						// Yes, there are existing postings for this position
						Set<ID> postIDSet = existingPostsMap.get(position.Id);
						// check if the current site id is one this position's current postings
						if (!postIDSet.contains(site.id)){
							Job_Posting__c post = new Job_Posting__c(Job_Posting_Site__c = site.id,Position__c = position.id);
							totalPosts.add(post);
						}
					} else {
						// No existing postings
						Job_Posting__c post = new Job_Posting__c(Job_Posting_Site__c = site.id,Position__c = position.id);
						totalPosts.add(post);
					}
				}
			}	
			System.debug('totalPosts.size()=' + totalPosts.size());
			// Now go through all the totalPosts and batch them up for insertion
			// 	- Max DML insert batchsize is 200
			for(Integer i=0; i < totalPosts.size(); i+=200){
				Integer endpoint = Math.min(i + 200, totalPosts.size());
				Integer numRecords = endpoint - i;
				System.debug('\n i=' + i);
				System.debug('endpoint=' + endpoint);
				System.debug('numRecords=' + numRecords);
				// create a new buffer
				postingBatch = new Job_Posting__c[numRecords];
				for(Integer j = 0; j < numRecords; j++){	
					postingBatch[j] = totalPosts[j+i];	
				}
				try{
					System.debug('postingBatch.size()=' + postingBatch.size());
					Database.SaveResult[] batchResults = Database.insert(postingBatch,false);
					totalResults.addAll(batchResults);
				} catch (Exception e){
					System.debug('error inserting:' + e);	
				}		
			} 
			// Now go through the results and send errors to the debug log
			Integer x = 0;
			for(Database.SaveResult result:totalResults){				
				if(!result.isSuccess()){
					// Get the first save result error
					Database.Error err = result.getErrors()[0];	
					posMap.get(totalPosts[x].Position__c).addError('Unable to create Job Posting for Position:'+ err.getMessage());				
				}
				x++;			
			}
		}
	} 
	
	public static void removePositionPostings(Set<ID> positionIdSet,Map<ID,Position__c> posMap){
		List<Database.DeleteResult> deleteResults = new List<Database.DeleteResult>();
		for (List<Job_Posting__c> deletePosts:[select id from Job_Posting__c where Position__c IN :positionIdSet]) {
			Database.DeleteResult[] batchResults = Database.delete(deletePosts,false);
			deleteResults.addAll(batchResults);
		}
		// now process all the results
		for (Database.DeleteResult result:deleteResults){
			if(!result.isSuccess()){
				// Get the first save result error
				Database.Error err = result.getErrors()[0];	
				posMap.get(result.getId()).addError('Unable to delete Job Posting for Position:'+ err.getMessage());				
			}				
		}
	}
}