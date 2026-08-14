#show: doc.with(
$if(title)$
  title: [$title$],
$endif$
$if(subtitle)$
  subtitle: [$subtitle$],
$endif$
$if(by-author)$
  author: (
$for(by-author)$
    "$it.name.literal$"$sep$,
$endfor$
  ),
$endif$
$if(date)$
  date: [$date$],
$endif$
$if(reference)$
  reference: [$reference$],
$endif$
$if(version)$
  version: [$version$],
$endif$
$if(confidentiality)$
  confidentiality: [$confidentiality$],
$endif$
$if(doc-type)$
  doc-type: [$doc-type$],
$endif$
$if(edition)$
  edition: [$edition$],
$endif$
$if(review-date)$
  review-date: [$review-date$],
$endif$
)
