This is a relatively simple little application written to serve as the final project in my [Beginning Objective-C book from Apress][book].

It implements a basic Core Data store for some simple Contacts data, and will import a starting set from the user's address book. The application is sandboxed, with access provided only to the Address Book API. It also makes its data available on the network (and browses for other contacts stores) using a sandboxed XPC bundle to implement the networking steps, including Bonjour browse and registration.

[book]: http://www.apress.com/9781430243687