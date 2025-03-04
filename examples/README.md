## Using the Mlang backends

Mlang translates the code for income tax computation to a number of different
target languages. For each of the target languages, there is a folder here
that illustrates how to use the files generated by the Mlang compiler, as
well as a wrapper that executes the tests on the generated code to ensure
that it remains correct with respect to the behavior of the original source
code.

To know more about using a particular Mlang backend, please read the dedicated
`README.md` inside the correct folder:

* [C](c/README.md)
* [Python](python/README.md)

### Configuring the generated file

The first thing to do is to figure out which parts of the income tax computation
you really need. This implies determining what would be your inputs and output
variables. Indeed, the income tax computation is structured around a set of
variables, which can either be :
* inputs of the earning statements (like the salary of a person);
* computed quantities (like the amount of taxes you owe).

Your application might not need to compute the income tax in a completely
general case; often you want to compute it in a simplified setting where not
all inputs can be filled by the user. The descriptions of the variables can be
found in the [tvgI.m](https://gitlab.adullact.net/dgfip/ir-calcul/-/tree/master/sources2018m_6_7/tgvI.m). You can also
figure out the input variables by looking at the 3-letters-and-numbers names
of the inputs in the
[official form](https://www3.impots.gouv.fr/simulateur/calcul_impot/2019/simplifie/index.htm),
and here is a list of common output variables:

* `IINET`: "Total de votre imposition"
* `IRNET`: "Total de votre imposition (si positif)"
* `NAPCR`: "Net a payer (CSG + CRDS)"
* `TXMOYIMP`: "Taux moyen d imposition"
* `REVKIRE`: "Revenu de reference"
* `NBPT`: "Nombre de parts"
* `IAN`: "Impot apres imputations non restituables"
* `CIMR`: "Credit impot modernisation du recouvrement"
* `CSG`: "CSG"
* `RDSN`: "CRDS"
* `PSOL`: "Contribution sociale et solidarite"

This configuration is done inside a `.m_spec` file which is later fed to Mlang.
See [the dedicated README](../m_specs/README.md) for the syntax and contents
of this configuration file.
