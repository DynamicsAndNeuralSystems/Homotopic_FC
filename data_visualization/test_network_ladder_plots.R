library(broom)
library(circlize)
library(ComplexHeatmap)
library(cowplot)
library(dendextend)
library(FactoMineR)
library(GGally)
library(ggseg)
library(glue)
library(grid)
library(patchwork)
library(see)
library(tidyverse)
library(ggraph)
library(tidygraph)
library(igraph)

theme_set(theme_cowplot())

data_path = "/Users/abry4213/data/HCP100/"

entorhinal_pearson_FC_res = read.csv('../data/test_entorhinal_out.csv')

# Load hierarchy-based DK maks
hierarchy_dk_neuromaps_res = read.csv('../data/hierarchy_dk_neuromaps_res.csv')
AHBA_PC1_based_hierarchy_order = hierarchy_dk_neuromaps_res %>% 
  filter(Description=='PC1 of Allen Human Brain Atlas') %>% 
  arrange(Value) %>% 
  distinct(Base_Region) %>% 
  pull(Base_Region)

###############################

inter_hemispheric_connection_lines <- entorhinal_pearson_FC_res %>% 
  filter(Connection_Type == "Inter-hemispheric") %>%
  mutate(base_region_from = "entorhinal") %>% 
  mutate(Connection_ID = row_number()) %>% 
  pivot_longer(cols=c(base_region_from, base_region_to), names_to="names", values_to="Base_Region") %>%
  select(-names) %>%
  rename("Pearson_R" = "Mean_Pearson_FC") %>%
  mutate(Base_Region = factor(Base_Region, levels=AHBA_PC1_based_hierarchy_order),
         Pearson_R = abs(Pearson_R),
         Connection_Type = factor(Connection_Type, levels=c("Intra-hemispheric", "Inter-hemispheric"))) %>% 
  group_by(Connection_ID) %>% 
  mutate(Connection_Type = c("Intra-hemispheric", "Inter-hemispheric"))

points_data_to_plot <- data.frame(Base_Region=rep(AHBA_PC1_based_hierarchy_order, 2),
                                  Value = rep(0, 68),
                                  Connection_Type = c(rep("Intra-hemispheric", 34),
                                                      rep("Inter-hemispheric", 34))) %>%
  mutate(Base_Region = factor(Base_Region, levels=AHBA_PC1_based_hierarchy_order),
         Connection_Type = factor(Connection_Type, levels=c("Intra-hemispheric", "Inter-hemispheric")))

inter_plot <- ggplot(mapping=aes(x=Connection_Type, y=Base_Region)) +
  geom_point(data=points_data_to_plot, aes(x=Connection_Type, y=Base_Region)) +
  geom_line(data=inter_hemispheric_connection_lines, aes(x=Connection_Type, y=Base_Region, 
                                                         group=Connection_ID, 
                                                         alpha=Pearson_R, linewidth=Pearson_R,
                                                         color=Pearson_R))+
  scale_x_discrete(expand=c(0.1, 0.1)) +
  scale_y_discrete(limits=rev, position = "right") +
  scale_color_gradient(low="gray90", high="darkred") +
  theme(legend.position='none')

# define nodes
nodes <- data.frame(node_name = rev(AHBA_PC1_based_hierarchy_order)) %>%
  mutate(node_name = factor(node_name, levels = rev(AHBA_PC1_based_hierarchy_order)))


# define edges
edges <- entorhinal_pearson_FC_res %>% 
  filter(Connection_Type == "Intra-hemispheric") %>%
  mutate(base_region_from = "entorhinal") %>% 
  mutate(Connection_ID = row_number()) %>% 
  rename("from" = "base_region_from",
         "to" = "base_region_to") %>% 
  mutate(Mean_Pearson_FC = abs(Mean_Pearson_FC)) %>%
  mutate(from = factor(from, levels=AHBA_PC1_based_hierarchy_order),
         to = factor(to, levels=AHBA_PC1_based_hierarchy_order)) %>%
  arrange(from, to)

# build network from nodes and edges
network <- tbl_graph(edges = edges, nodes = nodes, directed = FALSE)

# Extract layout and modify x/y coordinates
layout_data <- create_layout(network, layout = "linear")

# Swap x and y to align nodes along the y-axis
layout_data <- layout_data %>%
  mutate(temp = x, x = y, y = temp) %>%  # Swap x and y
  select(-temp)  # Remove temporary column

# Flip the x-axis only
layout_data$x <- -layout_data$x  
# Use the modified layout in ggraph
intra_plot <- ggraph(layout_data) +
  geom_edge_arc(aes(color = Mean_Pearson_FC,
                    width = Mean_Pearson_FC,
                    alpha = Mean_Pearson_FC)) +
  geom_node_point() +
  scale_edge_color_gradient(low="gray90", high="darkred") +
  theme(legend.position='none')

wrap_plots(list(intra_plot, inter_plot), widths=c(0.3, 0.7))
