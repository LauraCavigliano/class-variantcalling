## clone repository
cd /workspaces/class-variantcalling
mkdir -p analysis (io: analisi)
cd analysis

## sym link so we do not change the repository itself
mkdir -p raw_data
cd raw_data
ls -s /workspaces/class-variantcalling/datasets-class-variantcalling/reads/*.gz . (è un link simbolico che fa vedere il percorso dei file che terminano per .gz)
cd ..
mkdir -p alignment (creo cartella dove metto allineamento)
cd alignment

## now we can perform the alignment with BWA
appunti: il back slash è usato per "escapare" un carattere speciale e trasformarlo in un carattere come se fosse normale. Trucco per rendere più leggibile da terminare andare a capo così se metto / e vado a capo non significa eseguo comando ma spezza per rendere più ordinato e quindi / annulla in questo caso effetto dell'invio. bwa mem usato per allineamento o anche index (trasformata BWT ma noi non usiamo).
-t 2 \ --> primo comando dice quanti core del mio computer voglio usare per fare calcolo.
Poi do tre input in ordine predefinito a bwa: nome radice file di index con il suo percorso (/workspaces/class-variantcalling/datasets_reference_only/sequence/Homo_sapiens_assembly38_chr21.fasta \) non è references ma nome di partenza dei file che servono a bwa per fare BWT (vedi sequenze "datasets_reference_only"--> "sequence").
-R "@RG\tID:sim\tSM:normal\tPL:illumina\tLB:sim"--> dentro a questo read group ho ID del campione, nome campione stesso (qui normal) se faccio copia e incolla di questo e allineo le reads del malato quando faccio VC il software mette insieme tutte le reads saranno tutte normali e ne vede una sola e quindi devo farlo diverso se devo fare la differenza dei due campioni.
bwa produce formato SAM non BAM quindi devo trasformarlo.

bwa mem \ 
-t 2 \
-R "@RG\tID:sim\tSM:normal\tPL:illumina\tLB:sim" \ (è la descrizione del read group, con -R dico che le reads che sto allineando devono avere quel determinato read group)
/workspaces/class-variantcalling/datasets_reference_only/sequence/Homo_sapiens_assembly38_chr21.fasta \ (indici trasformata BWT)
/workspaces/class-variantcalling/analysis/raw_data/normal_1.000+disease_0.000_1.fq.gz \ (questo e successivo sono file F e R di un pair end)
/workspaces/class-variantcalling/analysis/raw_data/normal_1.000+disease_0.000_2.fq.gz \ (100% genoma normale e 0% di quello patologico)
| samtools view -@ 8 -bhS -o normal.bam - (conversione sam in bam alla fine - dice che devo prenderlo dal | e -@ è numero di processori in questo caso 2 )

Codice:
bwa mem \
-t 2 \ 
-R "@RG\tID:sim\tSM:normal\tPL:illumina\tLB:sim" \ 
/workspaces/class-variantcalling/datasets_reference_only/sequence/Homo_sapiens_assembly38_chr21.fasta \
/workspaces/class-variantcalling/analysis/raw_data/normal_1.000+disease_0.000_1.fq.gz \
/workspaces/class-variantcalling/analysis/raw_data/normal_1.000+disease_0.000_2.fq.gz \
| samtools view -@ 8 -bhS -o normal.bam -


## Real time: 176.099 sec; CPU: 256.669 sec
appunti: allineameno dei disease attendo nel codice ai processori.
bwa mem \
-t 2 \
-R "@RG\tID:sim\tSM:disease\tPL:illumina\tLB:sim" \
/workspaces/class-variantcalling/datasets_reference_only/sequence/Homo_sapiens_assembly38_chr21.fasta \
/workspaces/class-variantcalling/analysis/raw_data/normal_0.000+disease_1.000_1.fq.gz \
/workspaces/class-variantcalling/analysis/raw_data/normal_0.000+disease_1.000_2.fq.gz \
| samtools view -@ 8 -bhS -o disease.bam -

## Real time: 173.232 sec; CPU: 256.204 sec
appunti: samtool ha usato view come utility per conversione sam e bam, ma ha altre funzioni come sort che mette in ordine le mie reads in base alla posizione genomica in questo caso
e poi una volta ordinate le mettiamo indice.
1. ordinate cromosomiche per coordinate
2. creazione file .bai ossia indice

# sort the bam file (di default li mette in ordine di coordinata genomica)
samtools sort -o normal_sorted.bam normal.bam
samtools sort -o disease_sorted.bam disease.bam

# index the bam file (su file sortato e vediamo che abbiamo normal.bam e quello ordinato in coordinate cromosomiche e file .bam.bai che è indice di allineamento)
samtools index normal_sorted.bam
samtools index disease_sorted.bam


# Marking duplicates
appunti: poi fatto mark duplicated il comando per farlo gatk altri software (genome analysis toolkit) serve a manipolare allineamente e chiamare le varianti.
gatk marca duplicate e la base quality recalibration.
sintassi semplice -I input, -O file con duplicate marcate e -M file di log dove scrive metriche marcature es quante reads sono state marcate

gatk MarkDuplicates \
-I normal_sorted.bam \
-M normal_metrics.txt \
-O normal_md.bam (-o in minuscola per esempio in samtools e quindi sintassi abbastanza semplice)

gatk MarkDuplicates \
-I disease_sorted.bam \
-M disease_metrics.txt \
-O disease_md.bam


### recalibrating
appunti: questo step fatto da de steps primo calcolo di quanto deve essere ricalibrato e secondo passaggio di effettiva ricalibrazione
cambiando il QS


step1: calcolo
--> nel codice devo confrontare con references ecco perchè ho -R, poi devo passare due file uno raccolta delezioni inserzioni e quello prima di dbsnp per capire variazioni già descritte e noti
-o ossia output sono una tabella dove ho risultati di questi calcoli che mi dice di quanto devo ricalibrare.

gatk BaseRecalibrator \
   -I normal_md.bam \
   -R /workspaces/class-variantcalling/datasets_reference_only/sequence/Homo_sapiens_assembly38_chr21.fasta \
   --known-sites /workspaces/class-variantcalling/datasets_reference_only/gatkbundle/dbsnp_144.hg38_chr21.vcf.gz \
   --known-sites /workspaces/class-variantcalling/datasets_reference_only/gatkbundle/Mills_and_1000G_gold_standard.indels.hg38_chr21.vcf.gz \
   -O normal_recal_data.table

step2: applicazione
-->anche qui alla fine mi da una tabella alla fine.

gatk BaseRecalibrator \
   -I disease_md.bam \
   -R /workspaces/class-variantcalling/datasets_reference_only/sequence/Homo_sapiens_assembly38_chr21.fasta \
   --known-sites /workspaces/class-variantcalling/datasets_reference_only/gatkbundle/dbsnp_144.hg38_chr21.vcf.gz \
   --known-sites /workspaces/class-variantcalling/datasets_reference_only/gatkbundle/Mills_and_1000G_gold_standard.indels.hg38_chr21.vcf.gz \
   -O disease_recal_data.table


#### Apply recalibration i comandi sotto servono ad applicare su caso normale e caso

gatk ApplyBQSR \
   -R /workspaces/class-variantcalling/datasets_reference_only/sequence/Homo_sapiens_assembly38_chr21.fasta \
   -I normal_md.bam \
   --bqsr-recal-file normal_recal_data.table \
   -O normal_recal.bam

gatk ApplyBQSR \
   -R /workspaces/class-variantcalling/datasets_reference_only/sequence/Homo_sapiens_assembly38_chr21.fasta \
   -I disease_md.bam \
   --bqsr-recal-file disease_recal_data.table \
   -O disease_recal.bam

-->a questo punto se faccio ls -l *recal.b* dovrei avre 4 file che sono bam di ciascun campione e suoi allineamenti, index chiamato .bai da gatk non come prima samtools che da .bam.bai
--> se faccio ls -lh *recal.b* opzione h significa human readble e quindi scrive in ordine di grandezza comprensibile.



scaricare dati che sono molto grandi e quindi li salvo su computer e poi li ricarico su github
tar -zvcf alignments.tar.gz *_recal.b*