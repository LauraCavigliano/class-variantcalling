
### variant calling

cd /workspaces/class-variantcalling
mkdir -p analysis/variants
cd analysis/variants

-->fai anche una cartella dentro analysis che chiamo aligments e li carico il file zippato che avevo scaricato e poi decomprimo i file con comando sotto indicato
--> per decomprimere il file manda il comando: tar -xvzf aligments.tar.gz e così nella cartella ho i bam creati.
--> ho due cartelle sotto analysis una aligment dove ho allineamenti fatti e una variant che per ora è vuota

## first single sample discovery
appunti: codice da usare per haplotypecaller, ora identificazione varianti fatto per sample e quindi devo far correre haplotype callor due volte per campione normale e disease.
- primo comando è la java virtual machine e diamo 4 g di memoria per operazione che facciamo
- usiamo software in gatk di haplotypecaller e -R è la reference e quindi percorso reference, -I è input (faccio per normal sample e disease sample)
e -O dipende dal nome del VCF
- ERC dice a haplotypecaller dice di restituire un formato GVCF che riporta statistiche di varianti per analisi successive.

gatk --java-options "-Xmx4g" HaplotypeCaller  \
   -R /workspaces/class-variantcalling/datasets_reference_only/sequence/Homo_sapiens_assembly38_chr21.fasta \
   -I /workspaces/class-variantcalling/analysis/alignment/normal_recal.bam \
   -O normal.g.vcf.gz \
   -ERC GVCF

gatk --java-options "-Xmx4g" HaplotypeCaller  \
   -R /workspaces/class-variantcalling/datasets_reference_only/sequence/Homo_sapiens_assembly38_chr21.fasta \
   -I /workspaces/class-variantcalling/analysis/alignment/disease_recal.bam \
   -O disease.g.vcf.gz \
   -ERC GVCF

## then consolidate the 2 files
appunti: quando finisco di creare anche GVCF del secondo campione disease lo step successivo è il join genotyping e quindi devo mettere dati in uno stesso file.
1. importare entrambi i VCF in file chiamato da gatk database
2. usare questi database che portebbe contenere più di 2 campioni per chiamare genotipi su entrambi i campioni restituendo un file con le varianti di ambedue i campioni
--> quindi ultime colonne di file VCF, dopo la colona format, presentano i genotipi di ciascun campione per ciascuna variante in riga


appunti: creazione directory temporanea che serve a far funzionare la parte sotto

mkdir -p tmp


## combine the files into one
appunti: il codice che importa in database i due VCF si chiama GenomicsDBImport anche qui nome funzione intuitivo (DB database)
- prima parte con gatk abbastanza simile, le do una certa memoria, chiamo la funzione che importa nel database
- per ogni V passo i file che voglio importare nei databse quindi normal e disease
- genomicsdb-workspace-path da la cartella il percorso path per questo database che sto creando dove sto mportando entrambi i campioni
- -L intervallo che deve guardare nel nostro caso riferiamo solo al chr 21 e quindi dico di confinare input e poi analisi al chr 21
--> IMPORTA DATI E LI METTE IN UN PICCOLO DATABASE

gatk --java-options "-Xmx4g -Xms4g" GenomicsDBImport \
      -V normal.g.vcf.gz \
      -V disease.g.vcf.gz \
      --genomicsdb-workspace-path compared_db \
      --tmp-dir /workspaces/class-variantcalling/analysis/variants/tmp \
      -L chr21


## combine the files into one QUESTO NON LO FACCIAMO!
appunti: 
 gatk CombineGVCFs \
   -R /workspaces/class-variantcalling/datasets_reference_only/sequence/Homo_sapiens_assembly38_chr21.fasta \
   -V normal.g.vcf.gz \
   -V disease.g.vcf.gz \
   -O cohort.g.vcf.gz


### finally we can call the genotypes jointly
appunti: qui abbiamo GenotypeGVCFs come nome funzione in questo caso GVCF usato per assegnare genotipi
il formato del comando è simle abbiamo reference con -R, abbiamo -V dove passo database che ho creato.
- passo VCF con varianti identificate in dpsnp che (VCF ha colonna con ID variantese non faccio dbsnp quella colonna rimane vuota)
e quindi comando che serve ad assegnare codice identificativo se esiste


gatk --java-options "-Xmx4g" GenotypeGVCFs \
   -R /workspaces/class-variantcalling/datasets_reference_only/sequence/Homo_sapiens_assembly38_chr21.fasta \
   -V gendb://compared_db \
   --dbsnp /workspaces/class-variantcalling/datasets_reference_only/gatkbundle/dbsnp_146.hg38_chr21.vcf.gz \
   -O results.vcf.gz
   
--> ora nella cartella ho la cartella con minidatabase tmp, ho due file  GVCF e i file index (tbi) o indice del file relativo
sono con coordinate genomiche per questo formati file indice per facilitare accesso e con idice vado a vedere parte di interesse e non tutto.
quindi file index facilitano accesso ai dati!
alla fine ho un result.vcf.gz
--> zcat results.vcf.gz | more permette di vedere

### on ARM64 (Mac M1 chip) this code
### finally we can call the genotypes jointly
gatk --java-options "-Xmx4g" GenotypeGVCFs \
   -R /workspaces/class-variantcalling/datasets_reference_only/sequence/Homo_sapiens_assembly38_chr21.fasta \
   -V cohort.g.vcf.gz \
   --dbsnp /workspaces/class-variantcalling/datasets_reference_only/gatkbundle/dbsnp_146.hg38_chr21.vcf.gz \
   -O results.vcf.gz