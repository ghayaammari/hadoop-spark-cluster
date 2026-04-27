import java.io.IOException;

import org.apache.hadoop.conf.Configuration;
import org.apache.hadoop.fs.Path;
import org.apache.hadoop.io.DoubleWritable;
import org.apache.hadoop.io.Text;
import org.apache.hadoop.mapreduce.Job;
import org.apache.hadoop.mapreduce.Mapper;
import org.apache.hadoop.mapreduce.Reducer;
import org.apache.hadoop.mapreduce.lib.input.FileInputFormat;
import org.apache.hadoop.mapreduce.lib.output.FileOutputFormat;

/**
 * SalesPerCategory - Job MapReduce sur purchases.txt
 *
 * Format du fichier d'entrée (TSV, séparé par tabulations) :
 *   date \t heure \t ville \t catégorie \t montant \t paiement
 *
 * Ce job calcule le total des ventes (montant) par catégorie.
 *
 * Auteur: Ghaya Ammari - Big Data 2ème année ingénierie
 */
public class SalesPerCategory {

    // ─────────────────────────────────────────────
    // MAPPER
    // Entrée  : (offset, ligne_tsv)
    // Sortie  : (catégorie, montant)
    // ─────────────────────────────────────────────
    public static class SalesMapper
            extends Mapper<Object, Text, Text, DoubleWritable> {

        private Text category = new Text();
        private DoubleWritable amount = new DoubleWritable();

        @Override
        public void map(Object key, Text value, Context context)
                throws IOException, InterruptedException {

            String line = value.toString().trim();
            if (line.isEmpty()) return;

            // Découper la ligne par tabulation
            // Format : date \t heure \t ville \t catégorie \t montant \t paiement
            String[] fields = line.split("\t");

            // Vérifier qu'on a bien 6 colonnes
            if (fields.length < 6) return;

            String cat    = fields[3];   // colonne 4 : catégorie
            String amtStr = fields[4];   // colonne 5 : montant

            try {
                double amt = Double.parseDouble(amtStr);
                category.set(cat);
                amount.set(amt);
                // Émet : ("Men's Clothing", 214.05), ("Music", 66.08) ...
                context.write(category, amount);
            } catch (NumberFormatException e) {
                // Ligne mal formée → ignorer silencieusement
            }
        }
    }

    // ─────────────────────────────────────────────
    // REDUCER
    // Entrée  : (catégorie, [214.05, 247.18, ...])
    // Sortie  : (catégorie, total)
    // ─────────────────────────────────────────────
    public static class SalesReducer
            extends Reducer<Text, DoubleWritable, Text, DoubleWritable> {

        private DoubleWritable result = new DoubleWritable();

        @Override
        public void reduce(Text key, Iterable<DoubleWritable> values, Context context)
                throws IOException, InterruptedException {

            double total = 0.0;
            for (DoubleWritable val : values) {
                total += val.get();
            }
            result.set(Math.round(total * 100.0) / 100.0); // arrondi 2 décimales
            context.write(key, result);
            // Émet : ("Men's Clothing", 49823.50), ("Music", 31200.75) ...
        }
    }

    // ─────────────────────────────────────────────
    // DRIVER (main)
    // ─────────────────────────────────────────────
    public static void main(String[] args) throws Exception {

        if (args.length != 2) {
            System.err.println("Usage: SalesPerCategory <input_hdfs_path> <output_hdfs_path>");
            System.exit(1);
        }

        Configuration conf = new Configuration();
        Job job = Job.getInstance(conf, "Sales Per Category");

        job.setJarByClass(SalesPerCategory.class);

        job.setMapperClass(SalesMapper.class);
        job.setReducerClass(SalesReducer.class);

        // Types de sortie
        job.setOutputKeyClass(Text.class);
        job.setOutputValueClass(DoubleWritable.class);

        FileInputFormat.addInputPath(job, new Path(args[0]));
        FileOutputFormat.setOutputPath(job, new Path(args[1]));

        System.exit(job.waitForCompletion(true) ? 0 : 1);
    }
}
