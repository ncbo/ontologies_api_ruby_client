# ontologies_api_client

Models and serializers for ontologies and related artifacts backed by an 
[AllegroGraph](https://allegrograph.com/products/allegrograph/) or a [4store](https://github.com/4store/4store) 
database. This library can be used for interacting with an AllegroGraph or a 4store instance that 
stores [BioPortal](https://bioportal.bioontology.org/) ontology data. Models in the library are based on 
[Graph Oriented Objects for Ruby (Goo)](https://github.com/ncbo/goo). Serializers support RDF serialization as Rack Middleware and automatic 
generation of hypermedia links.

## Install

```
gem install ontologies_api_client
```

## Configuration

Configuration is provided by calling the <code>config</code> method

```ruby
require 'ontologies_api_client'
LinkedData::Client.config do |config|
  config.rest_url   = "http://stagedata.bioontology.org"
  config.apikey     = "your_apikey"
  config.links_attr = "links"
  config.cache      = false
end
```

## Usage

Once configured, you can utilize the existing resources that are defined 
(see <code>lib/ontologies_api_client/models</code>) to access a resource, 
its information, and related resources.

### Retrieval

There are multiple ways to retrieve individual or groups of resources.

***Find***

To retrieve a single record by ID:

```ruby
Category.find("http://data.bioontology.org/categories/all_organisms")
```

***Where***

To retrieve all records that match a particular in-code filter:

```ruby
categories = Category.where do |ont|
  ont.name.include?("health")
end
```

The code is a block that should return a boolean that indicates whether or not 
the item should be included in the results.

***Find By***

Use shortcut methods to find by particular attribute/value pairs:

```ruby
categories = Category.find_by_parentCategory("http://data.bioontology.org/categories/anatomy")
```

Attributes are named in the method and multiple can be provided by connecting them with 'and'.

## Create / Update / Delete

Creates are done via HTTP POST, update via HTTP PATCH, and deletes using HTTP DELETE.

### Create

```ruby
ontology_values = {
  acronym: "MY_ONT",
  name: "My Ontology",
  administeredBy: [http://data.bioontology.org/users/my_user]
}
ontology = LinkedData::Client::Models::Ontology.new(values: ontology_values)
response = ontology.save
puts ontology_saved.errors
```

### Update

```ruby
new_values = {
  administeredBy: [http://data.bioontology.org/users/my_other_user]
}
ontology = LinkedData::Client::Models::Ontology.find_by_acronym("MY_ONT")
ontology.update_from_params(params[:ontology])
response = ontology.update
puts response.errors
```

### Delete

```ruby
ontology = LinkedData::Client::Models::Ontology.find_by_acronym("MY_ONT")
response = ontology.delete
```

## Hypermedia Navigation

All resources have a collection of hypermedia links, available by calling the 'links' method.
These links can be navigated by calling the 'explore' method and chaining the link:

```ruby
ontology = Category.find("http://data.bioontology.org/categories/all_organisms")
classes = ontology.explore.classes
```

Links may contain a [URI template](http://tools.ietf.org/html/rfc6570). In this case, the template can be
populated by passing in ordered values for the template tokens:

```ruby
cls = ontology.explore.single_class("http://my.class.id/class1")
```

## Defining Resources

The client is designed to consume resources from the [NCBO Ontologies API](https://github.com/ncbo/ontologies_api).
Resources are defined in the client using media types that we know about and
providing attribute names that we want to retreive for each media type.

For example:

```ruby
class Category < LinkedData::Client::Base
  include LinkedData::Client::Collection
  @media_type = "http://data.bioontology.org/metadata/Category"
end
```

### Collections

Resources that are available via collections should include the Collection mixin (LinkedData::Client::Collection).
By 'collection', we mean that the all resources are available at a single endpoint.
For example, 'Ontology' is a resource with collections because you can see all ontologgies
at the "/ontologies" URL.

### Read/Write

Resources that should have save, update, and delete methods will need to include the ReadWrite mixin (LinkedData::Client::ReadWrite).

## Questions

For questions please email [support@bioontology.org](support@bioontology.org.)

## Contributors
<a href="https://github.com/ncbo/ontologies_api_ruby_client/graphs/contributors">
  <img src="https://contrib.rocks/image?repo=ncbo/ontologies_api_ruby_client" />
</a>

## License
The 2-Clause BSD License. See [LICENSE.txt](LICENSE.txt) for more information.
