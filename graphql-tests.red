Red [
	Title: "GraphQL tests"
]

tests: [
; ---[1]	
{
mutation {
  likeStory(storyID: 12345) {
	story {
	  likeCount
	}
  }
}		
}
; ---[2]
{
{
  me {
	id
	firstName
	lastName
	birthday {
	  month
	  day
	}
	friends {
	  name
	}
  }
}		
}
; ---[3]
{
# `me` could represent the currently logged in viewer.
{
  me {
	name
  }
}
}
; ---[4]
{
# `user` represents one of many users in a graph of data, referred to by a
# unique identifier.
{
  user(id: 4) {
	name
  }
}
}
; ---[5]
{
{
  user(id: 4) {
	id
	name
	profilePic(size: 100)
  }
}		
}
; ---[6]
{
{
  user(id: 4) {
	id
	name
	profilePic(width: 100, height: 50)
  }
}
}
; ---[7]
{
{
  user(id: 4) {
	id
	name
	smallPic: profilePic(size: 64)
	bigPic: profilePic(size: 1024)
  }
}
}
; ---[8]
{
query noFragments {
  user(id: 4) {
	friends(first: 10) {
	  id
	  name
	  profilePic(size: 50)
	}
	mutualFriends(first: 10) {
	  id
	  name
	  profilePic(size: 50)
	}
  }
}
}
; ---[9]
{
query withFragments {
  user(id: 4) {
	friends(first: 10) {
	  ...friendFields
	}
	mutualFriends(first: 10) {
	  ...friendFields
	}
  }
}

fragment friendFields on User {
  id
  name
  profilePic(size: 50)
}
	}
; ---[10]
{
query withNestedFragments {
  user(id: 4) {
	friends(first: 10) {
	  ...friendFields
	}
	mutualFriends(first: 10) {
	  ...friendFields
	}
  }
}

fragment friendFields on User {
  id
  name
  ...standardProfilePic
}

fragment standardProfilePic on User {
  profilePic(size: 50)
}
}
; ---[11]
{
query FragmentTyping {
  profiles(handles: ["zuck", "cocacola"]) {
	handle
	...userFragment
	...pageFragment
  }
}

fragment userFragment on User {
  friends {
	count
  }
}

fragment pageFragment on Page {
  likers {
	count
  }
}
}
; ---[12]
{
query inlineFragmentTyping {
  profiles(handles: ["zuck", "cocacola"]) {
	handle
	... on User {
	  friends {
		count
	  }
	}
	... on Page {
	  likers {
		count
	  }
	}
  }
}
}
; ---[13]
{
query inlineFragmentNoType($expandedInfo: Boolean) {
  user(handle: "zuck") {
	id
	name
	... @include(if: $expandedInfo) {
	  firstName
	  lastName
	  birthday
	}
  }
}
}
; ---[14] 
{
{
  entity {
    name
    ... on Person {
      age
    }
  },
  phoneNumber
}
}
]

test-query.graphql: {
query {
  repository(owner:"octocat", name:"Hello-World") {
    issues(last:20, states:CLOSED) {
      edges {
        node {
          title
          url
          labels(first:5) {
            edges {
              node {
                name
              }
            }
          }
        }
      }
    }
  }
}
}

test-query: [
	repository (owner: "octocat" name: "Hello-World") [
		issues (last: 20 states: CLOSED) [
			edges [
				node [
					title
					url
					labels (first: 5) [
						edges [
							node [
								name
							]
						]
					]
				]
			]
		]
	]
]
