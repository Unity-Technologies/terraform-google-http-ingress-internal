# Limitations


## Contents

* [Google Providers](#google-providers)
* [Error Handling](#error-handling)
* [Unused Resource Types](#unused-resource-types)


## Google Providers

This module uses the `google-beta` provider and allows the user to control
which version (via standard Terraform features for such).  We would like
to allow the user to pick between using the `google` and the `google-beta`
provider, but Terraform does not allow such flexibility with provider
usage in modules at this time.

You must use at least v4.30 of the `google-beta` provider as earlier
versions did not support Certificate Manager.

You must use at least Terraform v0.13 as the module uses some features
that were not available in earlier versions.


## Error Handling

Terraform does not provide a lot of great ways for modules to produce
informative error messages.  This is even more true since this module
currently supports the use of Terraform v0.13.

But this module tries hard to make sure that an explanation of what went
wrong gets included in the errors that get reported to you.  Unfortunately,
there are several scenarios where this explanation will appear in an odd
place.

For example, if you mispel the DNS Zone `.name` in `dns-zone-ref`, then many
steps will not succeed.  Without extra work by the module, many of these
failures would produce error messages that do not clearly point to the real
failure: being unable to look up your GCP-Managed DNS Zone.

Often, the best this module can do in such cases is to include the
explanation for the problem as part of a field in a `resource` block.  This
causes the error explanation to show up in the generated Terraform `plan`.
But the GCP Terraform providers are notoriously lax in what validation they
do during `plan`ning so even such obviously invalid values will likely not
cause the `plan` to fail.

But you can save yourself some time by reviewing the plan output for such
somewhat-hidden error explanations.  To make this easier, these error
explanations will always include the string "ERROR".

And if you miss some and do an `apply`, then the explanations will be
included in the error output, usually when it reports the value of a
resource field that was not valid.


## Unused Resource Types

There are ways to use this module (that you are unlikely to need) such that
no IP Address and/or no URL Map are used.  However, in order to keep the
complexity of the module under control, you still may have to provide
non-empty values for `ip-addr-ref` and/or `url-map-ref`.  Each of the
following values prevent the module from creating a resource while also
not requiring the existence of such a resource created elsewhere:

* `url-map-ref = "none"`; Any non-empty value works here as GCP does not
  even provide a way to look up an existing URL Map resource.

* `ip-addr-ref = ".none."`; Any value with no "/" characters and at least one
  "." character will work.  Such values are treated as a literal IP address,
  removing the need to look up resource details.

